#!/usr/bin/env -S deno run --allow-read --allow-write --allow-net --allow-run --allow-env

const home = Deno.env.get("HOME") ?? "/home/user";
const filePath = `${home}/.nixcfg/home.nix`;
const nixcfgDir = `${home}/.nixcfg`;
const port = 3000;

const appName = Deno.env.get("AMBIT_APP_NAME") ?? "openclaw";
const networkName = Deno.env.get("AMBIT_NETWORK_NAME") ?? "ambit";
const gatewayUrl = `http://${appName}.${networkName}:18789`;

function detectLang(path: string): string {
  const ext = path.split(".").pop()?.toLowerCase() ?? "";
  const map: Record<string, string> = {
    js: "javascript", ts: "javascript", jsx: "javascript", tsx: "javascript", json: "json", md: "markdown", markdown: "markdown", html: "html", htm: "html", css: "css", py: "python", rs: "rust", go: "go", sh: "shell", bash: "shell", zsh: "shell", yaml: "yaml", yml: "yaml", toml: "toml", sql: "sql", xml: "xml", cpp: "cpp", c: "cpp", java: "java", nix: "nix",
  };
  return map[ext] ?? "markdown";
}

const lang = detectLang(filePath);
const fileName = filePath.split("/").pop() ?? filePath;

const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>${fileName}</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    body {
      font-family: system-ui, sans-serif;
      background: #1a1b26;
      color: #c0caf5;
      height: 100vh;
      display: flex;
      flex-direction: column;
    }

    header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 10px 16px;
      background: #16161e;
      border-bottom: 1px solid #2a2b3d;
      flex-shrink: 0;
    }

    header .file {
      font-size: 13px;
      color: #7aa2f7;
      font-family: monospace;
      display: flex;
      align-items: center;
      gap: 8px;
    }

    header .dot {
      width: 8px; height: 8px;
      border-radius: 50%;
      background: #3d59a1;
      transition: background 0.2s;
    }
    header .dot.dirty { background: #e0af68; }

    header .actions { display: flex; gap: 8px; align-items: center; }

    #save-btn {
      padding: 6px 14px;
      border-radius: 6px;
      border: none;
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
      background: #7aa2f7;
      color: #1a1b26;
      transition: opacity 0.15s, background 0.2s;
    }
    #save-btn:hover:not(:disabled) { opacity: 0.85; }
    #save-btn:disabled {
      background: #2a2b3d;
      color: #565f89;
      cursor: default;
    }

    /* Status Badge */
    #status-badge {
      font-size: 11px;
      font-weight: 600;
      padding: 3px 8px;
      border-radius: 4px;
      font-family: monospace;
      transition: opacity 0.2s, background 0.2s, color 0.2s;
    }
    #status-badge.hidden { opacity: 0; }
    #status-badge.checking  { background: #e0af6833; color: #e0af68; }
    #status-badge.building  { background: #7aa2f733; color: #7aa2f7; }
    #status-badge.ok        { background: #9ece6a33; color: #9ece6a; }
    #status-badge.err       { background: #f7768e33; color: #f7768e; }

    /* Toasts */
    #toast-rack {
      position: fixed;
      bottom: 20px;
      right: 20px;
      display: flex;
      flex-direction: column;
      gap: 8px;
      z-index: 999;
      pointer-events: none;
    }
    .toast {
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 9px 14px;
      border-radius: 8px;
      font-size: 13px;
      font-weight: 500;
      background: #24283b;
      border: 1px solid #2a2b3d;
      box-shadow: 0 4px 16px rgba(0,0,0,0.4);
      color: #c0caf5;
      opacity: 0;
      transform: translateY(6px);
      transition: opacity 0.18s ease, transform 0.18s ease;
      pointer-events: none;
    }
    .toast.show { opacity: 1; transform: translateY(0); }
    .toast.hide { opacity: 0; transform: translateY(6px); }
    .toast .icon { font-size: 15px; line-height: 1; }
    .toast.ok   { border-color: #9ece6a44; }
    .toast.ok   .icon::before { content: "✓"; color: #9ece6a; }
    .toast.err  { border-color: #f7768e44; }
    .toast.err  .icon::before { content: "✕"; color: #f7768e; }

    #editor-wrap {
      flex: 1;
      overflow: hidden;
      display: flex;
      flex-direction: column;
    }

    .cm-editor {
      height: 100%;
      font-size: 14px;
    }
    .cm-scroller { overflow: auto; }

    /* Nice Scrollbar */
    ::-webkit-scrollbar { width: 8px; height: 8px; }
    ::-webkit-scrollbar-track { background: transparent; }
    ::-webkit-scrollbar-thumb { background: #2a2b3d; border-radius: 4px; }
  </style>
</head>
<body>
  <header>
    <div class="file">
      <span class="dot" id="dirty-dot"></span>
      <span>${fileName}</span>
      <span style="color:#565f89; font-size:11px">${lang}</span>
      <span id="status-badge" class="hidden"></span>
    </div>
    <div class="actions">
      <a href="${gatewayUrl}" target="_blank" style="padding:6px 14px; border-radius:6px; font-size:13px; font-weight:600; color:#7aa2f7; text-decoration:none; border:1px solid #2a2b3d; transition:opacity 0.15s;">Gateway</a>
      <button id="save-btn" disabled>Save</button>
    </div>
  </header>
  <div id="editor-wrap"></div>
  <div id="toast-rack"></div>

  <script type="module">
    import { EditorView, keymap, lineNumbers, highlightActiveLineGutter,
             highlightSpecialChars, drawSelection, dropCursor,
             rectangularSelection, crosshairCursor, highlightActiveLine }
      from "https://esm.sh/@codemirror/view@6";
    import { EditorState, Compartment } from "https://esm.sh/@codemirror/state@6";
    import { defaultKeymap, history, historyKeymap, indentWithTab }
      from "https://esm.sh/@codemirror/commands@6";
    import { foldGutter, indentOnInput, syntaxHighlighting,
             defaultHighlightStyle, bracketMatching, foldKeymap }
      from "https://esm.sh/@codemirror/language@6";
    import { closeBrackets, autocompletion, closeBracketsKeymap,
             completionKeymap } from "https://esm.sh/@codemirror/autocomplete@6";
    import { highlightSelectionMatches, searchKeymap } from "https://esm.sh/@codemirror/search@6";
    import { lintKeymap } from "https://esm.sh/@codemirror/lint@6";
    import { oneDark } from "https://esm.sh/@codemirror/theme-one-dark@6";

    const langLoaders = {
      javascript: () => import("https://esm.sh/@codemirror/lang-javascript@6").then(m => m.javascript({ typescript: true })),
      json:       () => import("https://esm.sh/@codemirror/lang-json@6").then(m => m.json()),
      markdown:   () => import("https://esm.sh/@codemirror/lang-markdown@6").then(m => m.markdown()),
      html:       () => import("https://esm.sh/@codemirror/lang-html@6").then(m => m.html()),
      css:        () => import("https://esm.sh/@codemirror/lang-css@6").then(m => m.css()),
      python:     () => import("https://esm.sh/@codemirror/lang-python@6").then(m => m.python()),
      rust:       () => import("https://esm.sh/@codemirror/lang-rust@6").then(m => m.rust()),
      cpp:        () => import("https://esm.sh/@codemirror/lang-cpp@6").then(m => m.cpp()),
      java:       () => import("https://esm.sh/@codemirror/lang-java@6").then(m => m.java()),
      sql:        () => import("https://esm.sh/@codemirror/lang-sql@6").then(m => m.sql()),
      xml:        () => import("https://esm.sh/@codemirror/lang-xml@6").then(m => m.xml()),
      yaml:       () => import("https://esm.sh/@codemirror/lang-yaml@6").then(m => m.yaml()),
      nix:        () => import("https://esm.sh/@replit/codemirror-lang-nix").then(m => m.nix()),
    };

    const res = await fetch("/api/content");
    const initialContent = await res.text();

    let langExt = [];
    const loader = langLoaders["${lang}"];
    if (loader) langExt = [await loader()];

    const saveBtn  = document.getElementById("save-btn");
    const dirtyDot = document.getElementById("dirty-dot");
    const badge    = document.getElementById("status-badge");
    const rack     = document.getElementById("toast-rack");
    let dirty = false;

    function toast(msg, kind = "ok", duration = 2800) {
      const el = document.createElement("div");
      el.className = "toast " + kind;
      el.innerHTML = \`<span class="icon"></span><span>\${msg}</span>\`;
      rack.appendChild(el);
      requestAnimationFrame(() => {
        requestAnimationFrame(() => el.classList.add("show"));
      });
      setTimeout(() => {
        el.classList.replace("show", "hide");
        el.addEventListener("transitionend", () => el.remove(), { once: true });
      }, duration);
    }

    function setDirty(val) {
      dirty = val;
      dirtyDot.classList.toggle("dirty", val);
      saveBtn.disabled = !val;
    }

    function setBadge(text, cls) {
      badge.textContent = text;
      badge.className = cls;
    }

    function clearBadge(delay = 3000) {
      setTimeout(() => { badge.className = "hidden"; }, delay);
    }

    const readOnlyComp = new Compartment();

    function setEditorLocked(locked) {
      view.dispatch({ effects: readOnlyComp.reconfigure(EditorState.readOnly.of(locked)) });
      saveBtn.disabled = locked || !dirty;
    }

    let rebuildPoll = null;

    function pollRebuild() {
      if (rebuildPoll) return;
      rebuildPoll = setInterval(async () => {
        try {
          const r = await fetch("/api/rebuild-status");
          const s = await r.json();
          if (s.status === "done") {
            clearInterval(rebuildPoll);
            rebuildPoll = null;
            if (s.ok) {
              setBadge("OK", "ok");
              toast("Rebuild Complete");
            } else {
              setBadge("Error", "err");
              toast("Rebuild Failed: " + (s.error || "Unknown"), "err", 6000);
            }
            clearBadge(5000);
          }
        } catch { /* ignore */ }
      }, 2000);
    }

    async function save() {
      if (!dirty) return;
      const content = view.state.doc.toString();

      setEditorLocked(true);
      setBadge("Checking...", "checking");

      try {
        const r = await fetch("/api/content", {
          method: "POST",
          headers: { "Content-Type": "text/plain" },
          body: content,
        });
        if (!r.ok) {
          const errText = await r.text();
          setEditorLocked(false);
          if (r.status === 422) {
            setBadge("Invalid", "err");
            toast(errText, "err", 6000);
          } else {
            setBadge("Error", "err");
            toast("Save Failed: " + errText, "err", 4000);
          }
          clearBadge(5000);
          return;
        }
        setEditorLocked(false);
        setDirty(false);
        setBadge("Rebuilding...", "building");
        toast("Saved");
        pollRebuild();
      } catch (e) {
        setEditorLocked(false);
        setBadge("Error", "err");
        toast("Save Failed: " + e.message, "err", 4000);
        clearBadge(5000);
      }
    }

    const view = new EditorView({
      state: EditorState.create({
        doc: initialContent,
        extensions: [
          lineNumbers(),
          highlightActiveLineGutter(),
          highlightSpecialChars(),
          history(),
          foldGutter(),
          drawSelection(),
          dropCursor(),
          EditorState.allowMultipleSelections.of(true),
          indentOnInput(),
          syntaxHighlighting(defaultHighlightStyle, { fallback: true }),
          bracketMatching(),
          closeBrackets(),
          autocompletion(),
          rectangularSelection(),
          crosshairCursor(),
          highlightActiveLine(),
          highlightSelectionMatches(),
          keymap.of([
            ...closeBracketsKeymap,
            ...defaultKeymap,
            ...searchKeymap,
            ...historyKeymap,
            ...foldKeymap,
            ...completionKeymap,
            ...lintKeymap,
            indentWithTab,
            { key: "Mod-s", run: () => { save(); return true; } },
          ]),
          oneDark,
          ...langExt,
          readOnlyComp.of(EditorState.readOnly.of(false)),
          EditorView.updateListener.of(update => {
            if (update.docChanged) setDirty(true);
          }),
          EditorView.theme({ "&": { height: "100%" } }),
        ],
      }),
      parent: document.getElementById("editor-wrap"),
    });

    saveBtn.addEventListener("click", save);

    // Warn on close if dirty
    window.addEventListener("beforeunload", e => {
      if (dirty) { e.preventDefault(); e.returnValue = ""; }
    });
  </script>
</body>
</html>`;

let rebuild = { status: "idle" as "idle" | "running" | "done", ok: true, error: "" };
let nextRebuild: PromiseWithResolvers<void> | null = null;

async function rebuildLoop() {
  while (true) {
    const gate = Promise.withResolvers<void>();
    nextRebuild = gate;
    await gate.promise;
    nextRebuild = null;

    rebuild = { status: "running", ok: true, error: "" };
    try {
      const cmd = new Deno.Command("home-manager", {
        args: ["switch", "--flake", nixcfgDir],
        cwd: nixcfgDir,
        stderr: "piped",
        stdout: "piped",
      });
      const out = await cmd.output();
      if (out.success) {
        rebuild = { status: "done", ok: true, error: "" };
      } else {
        const stderr = new TextDecoder().decode(out.stderr);
        rebuild = { status: "done", ok: false, error: stderr.slice(-500) };
      }
    } catch (e) {
      rebuild = { status: "done", ok: false, error: e instanceof Error ? e.message : String(e) };
    }
  }
}

function scheduleRebuild() {
  if (nextRebuild) nextRebuild.resolve();
}

rebuildLoop();

Deno.serve({ port }, async (req: Request) => {
  const url = new URL(req.url);

  if (url.pathname === "/" || url.pathname === "") {
    return new Response(html, {
      headers: { "Content-Type": "text/html; charset=utf-8" },
    });
  }

  // GET file content
  if (url.pathname === "/api/content" && req.method === "GET") {
    try {
      const content = await Deno.readTextFile(filePath);
      return new Response(content, {
        headers: { "Content-Type": "text/plain; charset=utf-8" },
      });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return new Response(msg, { status: 404 });
    }
  }

  // POST save content — validate with nix eval in a temp copy, then save and rebuild
  if (url.pathname === "/api/content" && req.method === "POST") {
    let tmpDir: string | undefined;
    try {
      const body = await req.text();

      tmpDir = await Deno.makeTempDir();
      const cp = new Deno.Command("cp", { args: ["-r", `${nixcfgDir}/.`, tmpDir] });
      await cp.output();
      await Deno.writeTextFile(`${tmpDir}/home.nix`, body);

      // Flakes require a git repo to discover files
      const init = new Deno.Command("git", { args: ["init"], cwd: tmpDir, stdout: "null", stderr: "null" });
      await init.output();
      const add = new Deno.Command("git", { args: ["add", "-A"], cwd: tmpDir, stdout: "null", stderr: "null" });
      await add.output();

      const check = new Deno.Command("nix", {
        args: ["eval", ".#homeConfigurations.user.activationPackage", "--json", "--accept-flake-config"],
        cwd: tmpDir,
        stderr: "piped",
        stdout: "piped",
      });
      const result = await check.output();

      if (!result.success) {
        const stderr = new TextDecoder().decode(result.stderr);
        return new Response(stderr.slice(-500).trim(), { status: 422 });
      }

      await Deno.writeTextFile(filePath, body);
      scheduleRebuild();

      return new Response("ok");
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return new Response(msg, { status: 500 });
    } finally {
      if (tmpDir) Deno.remove(tmpDir, { recursive: true }).catch(() => {});
    }
  }

  // GET rebuild status
  if (url.pathname === "/api/rebuild-status" && req.method === "GET") {
    return new Response(JSON.stringify(rebuild), {
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response("Not Found", { status: 404 });
});

console.log(`\n  Editor Ready →  http://localhost:${port}`);
console.log(`  File:            ${filePath}`);
console.log(`  Cmd+S / Ctrl+S to Save\n`);
