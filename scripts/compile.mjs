import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
execFileSync(
  process.execPath,
  [
    resolve("node_modules/elm/bin/elm"),
    "make",
    "src/Main.elm",
    "--optimize",
    "--output=src/elm.generated.js",
  ],
  { stdio: "inherit" },
);
const source = readFileSync("src/elm.generated.js", "utf8");
if (!source.trimEnd().endsWith("}(this));"))
  throw new Error("Formato de saída Elm inesperado.");
writeFileSync(
  "src/elm.generated.js",
  source.replace(/\}\(this\)\);\s*$/, "}(globalThis));"),
);
