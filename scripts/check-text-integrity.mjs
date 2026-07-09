import fs from "node:fs";
import path from "node:path";

const ROOTS = ["app", "components", "lib", "docs"];
const EXTRA_FILES = ["AGENTS.md", "README.md"];
const SOURCE_EXTENSIONS = new Set([".ts", ".tsx", ".js", ".jsx", ".mjs", ".md", ".json", ".css"]);
const SKIP_DIRS = new Set([".git", ".next", "node_modules", ".vercel"]);

const CHECKS = [
  { label: "mojibake U+00C3", pattern: /\u00c3/u },
  { label: "mojibake U+00C2", pattern: /\u00c2/u },
  { label: "mojibake U+00E2", pattern: /\u00e2/u },
  { label: "replacement character U+FFFD", pattern: /\ufffd/u },
  { label: "S?lo", pattern: /S\?lo/ },
  { label: "Podr?s", pattern: /Podr\?s/ },
  { label: "podr?n", pattern: /podr\?n/ },
  { label: "c?digo", pattern: /c\?digo/ },
  { label: "c?digos", pattern: /c\?digos/ },
  { label: "Correcci?n", pattern: /Correcci\?n/ },
  { label: "Confirmaci?n", pattern: /Confirmaci\?n/ },
  { label: "CONFIRMACI?N", pattern: /CONFIRMACI\?N/ },
  { label: "ocurri?", pattern: /ocurri\?/ },
  { label: "est?n", pattern: /est\?n/ },
  { label: "sesi?n", pattern: /sesi\?n/ },
  { label: "acci?n", pattern: /acci\?n/ },
  { label: "informaci?n", pattern: /informaci\?n/ },
];

function* walkDirectory(directory) {
  if (!fs.existsSync(directory)) return;

  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    if (SKIP_DIRS.has(entry.name)) continue;

    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      yield* walkDirectory(fullPath);
      continue;
    }

    if (SOURCE_EXTENSIONS.has(path.extname(entry.name))) {
      yield fullPath;
    }
  }
}

const files = new Set();
for (const root of ROOTS) {
  for (const file of walkDirectory(root)) files.add(file);
}
for (const file of EXTRA_FILES) {
  if (fs.existsSync(file)) files.add(file);
}

const findings = [];
for (const file of [...files].sort()) {
  const content = fs.readFileSync(file, "utf8");
  const lines = content.split(/\r?\n/);

  lines.forEach((line, index) => {
    for (const check of CHECKS) {
      if (check.pattern.test(line)) {
        findings.push({ file, lineNumber: index + 1, label: check.label, line });
      }
    }
  });
}

if (findings.length > 0) {
  console.error("Se encontraron posibles problemas de integridad de texto:\n");
  for (const finding of findings) {
    console.error(finding.file + ":" + finding.lineNumber + " [" + finding.label + "] " + finding.line);
  }
  process.exit(1);
}

console.log("Integridad de texto: OK");
