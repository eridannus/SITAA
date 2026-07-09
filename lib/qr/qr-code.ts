const VERSION = 6;
const SIZE = 21 + (VERSION - 1) * 4;
const DATA_CODEWORDS = 136;
const BLOCKS = 2;
const DATA_PER_BLOCK = 68;
const EC_PER_BLOCK = 18;

type Matrix = Array<Array<boolean | null>>;

const EXP = new Array<number>(512);
const LOG = new Array<number>(256);
let x = 1;
for (let i = 0; i < 255; i += 1) {
  EXP[i] = x;
  LOG[x] = i;
  x <<= 1;
  if (x & 0x100) x ^= 0x11d;
}
for (let i = 255; i < 512; i += 1) EXP[i] = EXP[i - 255];

function gfMul(left: number, right: number) {
  if (left === 0 || right === 0) return 0;
  return EXP[LOG[left] + LOG[right]];
}

function generatorPoly(degree: number) {
  let poly = [1];
  for (let i = 0; i < degree; i += 1) {
    const next = new Array(poly.length + 1).fill(0);
    for (let j = 0; j < poly.length; j += 1) {
      next[j] ^= gfMul(poly[j], EXP[i]);
      next[j + 1] ^= poly[j];
    }
    poly = next;
  }
  return poly;
}

function reedSolomon(data: number[], degree: number) {
  const gen = generatorPoly(degree);
  const message = [...data, ...new Array(degree).fill(0)];
  for (let i = 0; i < data.length; i += 1) {
    const coef = message[i];
    if (coef === 0) continue;
    for (let j = 0; j < gen.length; j += 1) message[i + j] ^= gfMul(gen[j], coef);
  }
  return message.slice(data.length);
}

function appendBits(bits: number[], value: number, length: number) {
  for (let i = length - 1; i >= 0; i -= 1) bits.push((value >> i) & 1);
}

function dataCodewords(input: string) {
  const bytes = new TextEncoder().encode(input);
  const maxBytes = DATA_CODEWORDS - 2;
  if (bytes.length > maxBytes) throw new Error("El enlace es demasiado largo para el QR local.");
  const bits: number[] = [];
  appendBits(bits, 0b0100, 4);
  appendBits(bits, bytes.length, 8);
  for (const byte of bytes) appendBits(bits, byte, 8);
  appendBits(bits, 0, Math.min(4, DATA_CODEWORDS * 8 - bits.length));
  while (bits.length % 8) bits.push(0);
  const codewords: number[] = [];
  for (let i = 0; i < bits.length; i += 8) {
    let value = 0;
    for (let j = 0; j < 8; j += 1) value = (value << 1) | bits[i + j];
    codewords.push(value);
  }
  for (let pad = 0; codewords.length < DATA_CODEWORDS; pad += 1) codewords.push(pad % 2 === 0 ? 0xec : 0x11);
  return codewords;
}

function emptyMatrix(): Matrix {
  return Array.from({ length: SIZE }, () => Array.from({ length: SIZE }, () => null));
}

function setModule(matrix: Matrix, reserved: boolean[][], row: number, col: number, value: boolean, isReserved = true) {
  if (row < 0 || col < 0 || row >= SIZE || col >= SIZE) return;
  matrix[row][col] = value;
  if (isReserved) reserved[row][col] = true;
}

function finder(matrix: Matrix, reserved: boolean[][], row: number, col: number) {
  for (let r = -1; r <= 7; r += 1) {
    for (let c = -1; c <= 7; c += 1) {
      const rr = row + r;
      const cc = col + c;
      const on = r >= 0 && r <= 6 && c >= 0 && c <= 6 && (r === 0 || r === 6 || c === 0 || c === 6 || (r >= 2 && r <= 4 && c >= 2 && c <= 4));
      setModule(matrix, reserved, rr, cc, on);
    }
  }
}

function alignment(matrix: Matrix, reserved: boolean[][], centerRow: number, centerCol: number) {
  for (let r = -2; r <= 2; r += 1) {
    for (let c = -2; c <= 2; c += 1) {
      const distance = Math.max(Math.abs(r), Math.abs(c));
      setModule(matrix, reserved, centerRow + r, centerCol + c, distance !== 1);
    }
  }
}

function setup(matrix: Matrix, reserved: boolean[][]) {
  finder(matrix, reserved, 0, 0);
  finder(matrix, reserved, 0, SIZE - 7);
  finder(matrix, reserved, SIZE - 7, 0);
  for (let i = 8; i < SIZE - 8; i += 1) {
    setModule(matrix, reserved, 6, i, i % 2 === 0);
    setModule(matrix, reserved, i, 6, i % 2 === 0);
  }
  alignment(matrix, reserved, 34, 34);
  setModule(matrix, reserved, 4 * VERSION + 9, 8, true);
  for (let i = 0; i < 9; i += 1) {
    if (i !== 6) {
      reserved[8][i] = true;
      reserved[i][8] = true;
    }
  }
  for (let i = 0; i < 8; i += 1) {
    reserved[8][SIZE - 1 - i] = true;
    reserved[SIZE - 1 - i][8] = true;
  }
}

function finalCodewords(input: string) {
  const data = dataCodewords(input);
  const blocks = Array.from({ length: BLOCKS }, (_, index) => data.slice(index * DATA_PER_BLOCK, (index + 1) * DATA_PER_BLOCK));
  const ecc = blocks.map((block) => reedSolomon(block, EC_PER_BLOCK));
  const result: number[] = [];
  for (let i = 0; i < DATA_PER_BLOCK; i += 1) for (const block of blocks) result.push(block[i]);
  for (let i = 0; i < EC_PER_BLOCK; i += 1) for (const block of ecc) result.push(block[i]);
  return result;
}

function formatBits() {
  const data = 0b01000;
  let value = data << 10;
  const poly = 0b10100110111;
  for (let i = 14; i >= 10; i -= 1) if ((value >> i) & 1) value ^= poly << (i - 10);
  return ((data << 10) | value) ^ 0b101010000010010;
}

function placeFormat(matrix: Matrix) {
  const bits = formatBits();
  const get = (i: number) => Boolean((bits >> i) & 1);
  const first = [[8,0],[8,1],[8,2],[8,3],[8,4],[8,5],[8,7],[8,8],[7,8],[5,8],[4,8],[3,8],[2,8],[1,8],[0,8]];
  const second = [[SIZE-1,8],[SIZE-2,8],[SIZE-3,8],[SIZE-4,8],[SIZE-5,8],[SIZE-6,8],[SIZE-7,8],[8,SIZE-8],[8,SIZE-7],[8,SIZE-6],[8,SIZE-5],[8,SIZE-4],[8,SIZE-3],[8,SIZE-2],[8,SIZE-1]];
  for (let i = 0; i < 15; i += 1) {
    const bit = get(i);
    matrix[first[i][0]][first[i][1]] = bit;
    matrix[second[i][0]][second[i][1]] = bit;
  }
}

function placeData(matrix: Matrix, reserved: boolean[][], codewords: number[]) {
  const bits: number[] = [];
  for (const codeword of codewords) appendBits(bits, codeword, 8);
  let bitIndex = 0;
  let upward = true;
  for (let col = SIZE - 1; col > 0; col -= 2) {
    if (col === 6) col -= 1;
    for (let step = 0; step < SIZE; step += 1) {
      const row = upward ? SIZE - 1 - step : step;
      for (let offset = 0; offset < 2; offset += 1) {
        const c = col - offset;
        if (reserved[row][c]) continue;
        let bit = bitIndex < bits.length ? bits[bitIndex] === 1 : false;
        bitIndex += 1;
        if ((row + c) % 2 === 0) bit = !bit;
        matrix[row][c] = bit;
      }
    }
    upward = !upward;
  }
}

export function qrSvgDataUri(input: string) {
  const matrix = emptyMatrix();
  const reserved = Array.from({ length: SIZE }, () => Array.from({ length: SIZE }, () => false));
  setup(matrix, reserved);
  placeData(matrix, reserved, finalCodewords(input));
  placeFormat(matrix);
  const quiet = 4;
  const viewSize = SIZE + quiet * 2;
  const rects: string[] = [];
  for (let row = 0; row < SIZE; row += 1) {
    for (let col = 0; col < SIZE; col += 1) {
      if (matrix[row][col]) rects.push('<rect x="' + (col + quiet) + '" y="' + (row + quiet) + '" width="1" height="1"/>');
    }
  }
  const svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + viewSize + ' ' + viewSize + '" shape-rendering="crispEdges"><rect width="100%" height="100%" fill="white"/><g fill="#0f172a">' + rects.join("") + '</g></svg>';
  return 'data:image/svg+xml;utf8,' + encodeURIComponent(svg);
}
