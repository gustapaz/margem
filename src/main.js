import "./elm.generated.js";
import "./style.css";
const storageKey = "margem-caderno-v1";
let saved = null;
let error = "";
try {
  const value = localStorage.getItem(storageKey);
  saved = value ? JSON.parse(value) : null;
} catch {
  error =
    "Não foi possível ler o armazenamento local. Você pode escrever nesta sessão.";
}
const app = globalThis.Elm.Main.init({
  node: document.getElementById("app"),
  flags: { saved, error },
});
const send = (tag, message = "", extra = {}) =>
  app.ports.received.send({ tag, message, ...extra });
let pending = null;
let timer;
const flush = () => {
  if (!pending) return;
  try {
    localStorage.setItem(storageKey, JSON.stringify(pending));
    pending = null;
    send("saved");
  } catch {
    send(
      "error",
      "O navegador não conseguiu salvar o caderno. O espaço pode estar cheio ou bloqueado.",
    );
  }
};
app.ports.persist.subscribe((value) => {
  pending = value;
  clearTimeout(timer);
  timer = setTimeout(flush, 350);
});
window.addEventListener("pagehide", flush);
document.addEventListener("visibilitychange", () => {
  if (document.hidden) flush();
});
let previousFocus = null;
const filePicker = document.createElement("input");
filePicker.type = "file";
filePicker.accept = ".json,application/json";
filePicker.hidden = true;
filePicker.setAttribute("aria-label", "Arquivo de backup do Margem");
document.body.append(filePicker);
filePicker.addEventListener("change", async () => {
  const file = filePicker.files?.[0];
  filePicker.value = "";
  if (!file) return;
  if (file.size > 50 * 1024 * 1024) {
    send(
      "notice",
      "Este arquivo ultrapassa 50 MB. Escolha um backup menor do Margem.",
    );
    return;
  }
  try {
    send("imported", "", { data: JSON.parse(await file.text()) });
  } catch {
    send(
      "notice",
      "Não foi possível ler este JSON. Nenhum texto foi alterado.",
    );
  }
});
app.ports.effects.subscribe((effect) => {
  if (effect.tag === "download") {
    flush();
    const filename = effect.name
      .normalize("NFC")
      .replace(/[<>:"/\\|?*\u0000-\u001f]/g, "-")
      .slice(0, 150);
    const url = URL.createObjectURL(
      new Blob([effect.content], { type: effect.mime }),
    );
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = filename;
    document.body.append(anchor);
    anchor.click();
    anchor.remove();
    setTimeout(() => URL.revokeObjectURL(url), 30000);
    send(
      "notice",
      "Arquivo preparado para download. Guarde sua cópia em um lugar seguro.",
    );
    return;
  }
  if (effect.tag === "import") {
    filePicker.click();
    return;
  }
  if (effect.tag === "dialog") previousFocus = document.activeElement;
  requestAnimationFrame(() => {
    const target = document.getElementById(effect.value);
    if (effect.tag === "dialog" && target instanceof HTMLDialogElement) {
      target.showModal();
      target.addEventListener(
        "cancel",
        (event) => {
          event.preventDefault();
          send("dismiss");
        },
        { once: true },
      );
      target.addEventListener("keydown", (event) => {
        if (event.key !== "Tab") return;
        const nodes = [
          ...target.querySelectorAll(
            "button:not([disabled]),input:not([disabled]),select:not([disabled]),a[href]",
          ),
        ];
        const first = nodes[0],
          last = nodes.at(-1);
        if (event.shiftKey && document.activeElement === first) {
          event.preventDefault();
          last?.focus();
        } else if (!event.shiftKey && document.activeElement === last) {
          event.preventDefault();
          first?.focus();
        }
      });
    } else if (effect.tag === "restore-focus") {
      (previousFocus?.isConnected ? previousFocus : target)?.focus();
    } else {
      target?.focus();
      if (effect.tag === "page")
        window.scrollTo({ top: 0, behavior: "instant" });
    }
  });
});
document.addEventListener("click", (event) => {
  if (event.target.closest?.(".skip")) {
    event.preventDefault();
    document.getElementById("main-content")?.focus();
  }
});
