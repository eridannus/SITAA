import { readdir, readFile } from "node:fs/promises";
import { extname, relative, resolve } from "node:path";

const root = process.cwd();
const scanRoots = ["app", "components"];
const extensions = new Set([".tsx", ".css"]);

// Excepción deliberada: fondo blanco calculado al convertir el SVG del QR a PNG.
const allowedHex = new Map([
  ["app/activities/[id]/checkin/attendance-checkin-manager.tsx", new Set(["#ffffff"])],
]);

const prohibited = [
  { name: "utilidad emerald heredada", pattern: /\b[\w:[\]/.-]*emerald-[\w/.-]+/g },
  { name: "utilidad verde fuera del contrato semántico", pattern: /\b(?:bg|text|border|ring|decoration|from|via|to)-green-\d{2,3}(?:\/\d+)?\b/g },
  { name: "posible texto oscuro sobre fondo oscuro", pattern: /\bbg-(?:blue|slate)-(?:800|900|950)\b[^\n"']*\btext-(?:blue|slate)-(?:700|800|900|950)\b/g },
  { name: "botón relleno legacy; usa una acción semántica", pattern: /rounded-(?:full|xl)[^\n"']*\bbg-(?:blue|red|amber|slate)-(?:700|800|900)\b/g },
];

async function collect(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const path = resolve(directory, entry.name);
    if (entry.isDirectory()) files.push(...await collect(path));
    else if (extensions.has(extname(entry.name))) files.push(path);
  }
  return files;
}

const findings = [];
for (const scanRoot of scanRoots) {
  for (const file of await collect(resolve(root, scanRoot))) {
    const projectPath = relative(root, file).replaceAll("\\", "/");
    const lines = (await readFile(file, "utf8")).split(/\r?\n/);
    lines.forEach((line, index) => {
      for (const rule of prohibited) {
        rule.pattern.lastIndex = 0;
        for (const match of line.matchAll(rule.pattern)) {
          findings.push({ file: projectPath, line: index + 1, rule: rule.name, value: match[0] });
        }
      }
      if (projectPath.endsWith(".tsx")) {
        for (const match of line.matchAll(/#[0-9a-fA-F]{3,8}\b/g)) {
          if (!allowedHex.get(projectPath)?.has(match[0].toLowerCase())) {
            findings.push({ file: projectPath, line: index + 1, rule: "hexadecimal arbitrario en TSX", value: match[0] });
          }
        }
      }
    });
  }
}

if (findings.length) {
  console.error("Consistencia UI: se encontraron patrones prohibidos:\n");
  for (const finding of findings) {
    console.error(`${finding.file}:${finding.line} [${finding.rule}] ${finding.value}`);
  }
  process.exit(1);
}

console.log("Consistencia UI: OK");
