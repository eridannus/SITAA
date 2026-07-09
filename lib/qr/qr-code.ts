import QRCode from "qrcode";

type QrSvgOptions = {
  type: "svg";
  width: number;
  margin: number;
  errorCorrectionLevel: "M";
  color: {
    dark: string;
    light: string;
  };
};

function toSvg(text: string) {
  return QRCode.toString(text, {
    type: "svg",
    width: 320,
    margin: 4,
    errorCorrectionLevel: "M",
    color: {
      dark: "#0f172a",
      light: "#ffffff",
    },
  } satisfies QrSvgOptions);
}

export async function qrSvgDataUri(input: string) {
  const value = input.trim();

  if (!value) return null;

  try {
    const svg = await toSvg(value);
    return "data:image/svg+xml;utf8," + encodeURIComponent(svg);
  } catch {
    return null;
  }
}
