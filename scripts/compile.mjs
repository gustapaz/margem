import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
const compiler = resolve("node_modules/elm/bin/elm");
const args = [
  "make",
  "src/Main.elm",
  "--optimize",
  "--output=src/elm.generated.js",
];
// No Windows o pacote mantém um wrapper Node; no Unix ele instala o binário aqui.
const windows = process.platform === "win32";
execFileSync(
  windows ? process.execPath : compiler,
  windows ? [compiler, ...args] : args,
  { stdio: "inherit" },
);
const source = readFileSync("src/elm.generated.js", "utf8");
if (!source.trimEnd().endsWith("}(this));"))
  throw new Error("Formato de saída Elm inesperado.");
writeFileSync(
  "src/elm.generated.js",
  source.replace(/\}\(this\)\);\s*$/, "}(globalThis));"),
);
