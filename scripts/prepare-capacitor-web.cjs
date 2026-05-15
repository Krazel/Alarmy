const fs = require("fs");
const path = require("path");

const root = process.cwd();
const outDir = path.join(root, "www");
const entries = [
  "index.html",
  "styles.css",
  "app.js",
  "manifest.json",
  "sw.js",
  "icons",
  "src",
];

function copyRecursive(source, target) {
  const stat = fs.statSync(source);
  if (stat.isDirectory()) {
    fs.mkdirSync(target, { recursive: true });
    for (const entry of fs.readdirSync(source)) {
      copyRecursive(path.join(source, entry), path.join(target, entry));
    }
    return;
  }

  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.copyFileSync(source, target);
}

fs.rmSync(outDir, { recursive: true, force: true });
fs.mkdirSync(outDir, { recursive: true });

for (const entry of entries) {
  copyRecursive(path.join(root, entry), path.join(outDir, entry));
}

console.log(`Prepared Capacitor web bundle at ${outDir}`);
