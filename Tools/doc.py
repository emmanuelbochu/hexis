#!/usr/bin/env python3
"""Builds docs/index.html (one self-contained page, no CDN) from docs/*.md, and refreshes the figures of README.md.

Facts that must never go stale (file counts, schema version, models, services, tests, program) are read from the code and
injected where a doc has a `<!-- auto:name -->` line. Usage: python3 Tools/doc.py          write docs/index.html
                                                              python3 Tools/doc.py --check  fail if it is out of date
"""
from __future__ import annotations

import glob
import html
import json
import os
import re
import subprocess
import sys
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "docs")
OUT = os.path.join(DOCS, "index.html")


def read(path: str) -> str:
    with open(path, encoding="utf-8") as f:
        return f.read()


def swift_files(sub: str) -> list[str]:
    return sorted(glob.glob(os.path.join(ROOT, sub, "**", "*.swift"), recursive=True))


def line_count(paths: list[str]) -> int:
    return sum(read(p).count("\n") for p in paths)


# ---- facts generated from the code ----

def fact_chiffres() -> str:
    rows = ["| Dossier | Fichiers Swift | Lignes |", "|---|---|---|"]
    total_f = total_l = 0
    for sub in ["Hexis/App", "Hexis/Theme", "Hexis/Models", "Hexis/Features", "Hexis/Services", "Hexis/Components",
                "HexisWidgets", "HexisShared"]:
        files = swift_files(sub)
        total_f, total_l = total_f + len(files), total_l + line_count(files)
        rows.append(f"| `{sub}` | {len(files)} | {line_count(files)} |")
    rows.append(f"| **Total** | **{total_f}** | **{total_l}** |")
    schemas = sorted(int(m.group(1)) for p in swift_files("Hexis/Models/Schema")
                     if (m := re.search(r"SchemaV(\d+)\.swift$", p)))
    tests = sum(read(p).count("@Test") for p in swift_files("Tools/LogicTests/Tests"))
    life = read(os.path.join(ROOT, "Tools/LogicTests/Tests/LogicTests/Life/LifeTests.swift")).count("@Test")
    program = json.loads(read(os.path.join(ROOT, "Hexis/Resources/Program.json")))
    exos = {e["name"] for w in program["workouts"] for b in w["blocks"] for e in b.get("exercises", [])}
    facts = [
        f"- Schéma SwiftData actuel : **V{schemas[-1]}**",
        f"- Programme actif : **{program['name']}**, {len(program['workouts'])} séances "
        f"({', '.join(w['name'] for w in program['workouts'])}), {len(exos)} exercices",
        f"- Tests : **{tests}** (dont **{life}** scénarios de vie simulée)",
    ]
    return "\n".join(rows + [""] + facts + ["", last_commit_line()])


def last_commit_line() -> str:
    try:
        out = subprocess.run(["git", "log", "-1", "--format=%h · %cs"], cwd=ROOT, capture_output=True, text=True).stdout
    except OSError:
        out = ""
    return f"Dernier commit : {out.strip() or 'inconnu'}"


def fact_modeles() -> str:
    names = []
    for p in swift_files("Hexis/Models"):
        names += re.findall(r"@Model\s+(?:final\s+)?class\s+(\w+)", read(p))
    return ", ".join(f"`{n}`" for n in sorted(names))


def fact_services() -> str:
    rows = ["| Service | Rôle |", "|---|---|"]
    for p in swift_files("Hexis/Services"):
        src = read(p)
        m = re.search(r"^///\s*(.+)$", src, re.M) or re.search(r"^\s*///\s*(.+)$", src, re.M)
        summary = m.group(1).replace("|", "/") if m else "(à documenter)"
        rows.append(f"| `{os.path.basename(p)[:-6]}` | {summary} |")
    return "\n".join(rows)


FACTS = {"chiffres": fact_chiffres, "modeles": fact_modeles, "services": fact_services}


def inject(text: str) -> str:
    return re.sub(r"<!-- auto:(\w+) -->", lambda m: FACTS[m.group(1)](), text)


# ---- minimal Markdown ----

def inline(s: str) -> str:
    s = html.escape(s, quote=False)
    s = re.sub(r"`([^`]+)`", r"<code>\1</code>", s)
    s = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", s)
    s = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", lambda m: f'<a href="{link(m.group(2))}">{m.group(1)}</a>', s)
    return s


def link(target: str) -> str:
    return "#" + target[:-3] if re.match(r"^\d\d-[\w-]+\.md$", target) else target


def slug(s: str) -> str:
    plain = unicodedata.normalize("NFKD", re.sub(r"[`*]", "", s).lower()).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", plain).strip("-")


def split_row(line: str) -> list[str]:
    return [c.strip() for c in line.strip().strip("|").split("|")]


def render(md: str, stem: str) -> tuple[str, list[tuple[str, str]]]:
    out: list[str] = []
    toc: list[tuple[str, str]] = []
    lines = md.split("\n")
    i = 0
    while i < len(lines):
        line = lines[i]
        if line.startswith("```"):
            j = i + 1
            while j < len(lines) and not lines[j].startswith("```"):
                j += 1
            out.append("<pre><code>" + html.escape("\n".join(lines[i + 1:j])) + "</code></pre>")
            i = j + 1
        elif line.startswith("<svg"):
            j = i
            while "</svg>" not in lines[j]:
                j += 1
            out.append('<figure class="schema">' + "\n".join(lines[i:j + 1]) + "</figure>")
            i = j + 1
        elif line.startswith("#"):
            level = len(line) - len(line.lstrip("#"))
            title = line[level:].strip()
            if level == 1:
                out.append(f"<h1>{inline(title)}</h1>")
            else:
                hid = f"{stem}-{slug(title)}"
                if level == 2:
                    toc.append((hid, re.sub(r"[`*]", "", title)))
                out.append(f'<h{level} id="{hid}">{inline(title)}</h{level}>')
            i += 1
        elif line.startswith("|") and i + 1 < len(lines) and re.match(r"^\|[\s:|-]+\|$", lines[i + 1]):
            head = split_row(line)
            rows = []
            i += 2
            while i < len(lines) and lines[i].startswith("|"):
                rows.append(split_row(lines[i]))
                i += 1
            t = "<div class=\"table\"><table><thead><tr>" + "".join(f"<th>{inline(c)}</th>" for c in head) + "</tr></thead><tbody>"
            for r in rows:
                t += "<tr>" + "".join(f"<td>{inline(c)}</td>" for c in r) + "</tr>"
            out.append(t + "</tbody></table></div>")
        elif re.match(r"^(- |\d+\. )", line):
            ordered = line[0].isdigit()
            tag = "ol" if ordered else "ul"
            items = []
            while i < len(lines) and re.match(r"^(- |\d+\. )", lines[i]):
                items.append(re.sub(r"^(- |\d+\. )", "", lines[i]))
                i += 1
            out.append(f"<{tag}>" + "".join(f"<li>{inline(x)}</li>" for x in items) + f"</{tag}>")
        elif line.strip() == "":
            i += 1
        else:
            para = []
            while i < len(lines) and lines[i].strip() and not re.match(r"^(#|\||- |\d+\. |```|<svg)", lines[i]):
                para.append(lines[i])
                i += 1
            if not para:  # a stray table row or similar: shown as text, never an endless loop
                para.append(lines[i])
                i += 1
            out.append("<p>" + inline(" ".join(para)) + "</p>")
    return "\n".join(out), toc


# ---- page ----

CSS = """
:root{--bg:#fff;--fg:#1d1d1f;--mute:#6e6e73;--line:#e5e5ea;--side:#f5f5f7;--accent:#0a7d5a;--code:#f0f0f3}
@media(prefers-color-scheme:dark){:root{--bg:#000;--fg:#f2f2f7;--mute:#9a9aa0;--line:#2c2c2e;--side:#111113;--accent:#34d3a0;--code:#1c1c1e}}
*{box-sizing:border-box}html{scroll-behavior:smooth;scroll-padding-top:16px}
body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
nav{position:fixed;inset:0 auto 0 0;width:280px;background:var(--side);border-right:1px solid var(--line);overflow:auto;padding:16px}
nav input{width:100%;padding:8px 10px;border:1px solid var(--line);border-radius:8px;background:var(--bg);color:var(--fg);font:inherit}
nav a{display:block;color:var(--fg);text-decoration:none;padding:4px 8px;border-radius:6px;font-size:14px}
nav a.top{font-weight:600;margin-top:8px}nav a.sub{color:var(--mute);padding-left:20px}
nav a.on{background:var(--code);color:var(--accent)}nav details{margin:0}nav summary{list-style:none;cursor:pointer}
main{margin-left:280px;padding:32px 24px 96px}section{max-width:760px;margin:0 auto 64px}
h1{font-size:30px;margin:0 0 16px}h2{font-size:21px;margin:32px 0 8px;padding-top:8px;border-top:1px solid var(--line)}
h3{font-size:17px;margin:20px 0 4px}a{color:var(--accent)}code{background:var(--code);padding:1px 5px;border-radius:5px;font-size:.88em}
pre{background:var(--code);padding:12px;border-radius:8px;overflow:auto}pre code{padding:0}
.table{overflow-x:auto;margin:12px 0}table{border-collapse:collapse;font-size:14px;width:100%}
th,td{border-bottom:1px solid var(--line);padding:6px 10px;text-align:left;vertical-align:top}th{color:var(--mute);font-weight:600}
li{margin:2px 0}.schema{margin:16px 0;text-align:center}.schema svg{max-width:100%;height:auto}
.schema .box{fill:var(--side);stroke:var(--line)}.schema .hot{fill:none;stroke:var(--accent);stroke-width:2}
.schema text{fill:var(--fg);font:13px -apple-system,sans-serif}.schema .arrow{stroke:var(--mute);stroke-width:1.5;fill:none}
.schema marker path{fill:var(--mute)}
#menu{display:none;position:fixed;top:8px;left:8px;z-index:5;padding:6px 12px;border:1px solid var(--line);border-radius:8px;
background:var(--side);color:var(--fg);font:inherit}
@media(max-width:860px){nav{transform:translateX(-100%);transition:transform .2s;z-index:4;width:84%}nav.open{transform:none}
main{margin-left:0;padding:56px 16px 96px}#menu{display:block}}
"""

JS = """
const nav=document.querySelector('nav'),links=[...nav.querySelectorAll('a')],secs=[...document.querySelectorAll('section')];
document.getElementById('menu').onclick=()=>nav.classList.toggle('open');
links.forEach(a=>a.addEventListener('click',()=>nav.classList.remove('open')));
document.getElementById('q').addEventListener('input',e=>{
  const q=e.target.value.trim().toLowerCase();
  secs.forEach(s=>{s.hidden=q&&!s.textContent.toLowerCase().includes(q)});
  nav.querySelectorAll('details').forEach(d=>{d.hidden=q&&document.getElementById(d.dataset.sec).hidden});
});
const io=new IntersectionObserver(es=>es.forEach(e=>{if(e.isIntersecting){
  links.forEach(a=>a.classList.toggle('on',a.getAttribute('href')==='#'+e.target.id));}}),{rootMargin:'-10% 0px -80% 0px'});
document.querySelectorAll('section,h2').forEach(el=>io.observe(el));
"""


def build() -> str:
    names = sorted(n for n in os.listdir(DOCS) if re.match(r"^\d\d-.+\.md$", n))
    navs, secs = [], []
    for name in names:
        stem = name[:-3]
        body, toc = render(inject(read(os.path.join(DOCS, name))), stem)
        title = re.search(r"^# (.+)$", read(os.path.join(DOCS, name)), re.M).group(1)
        subs = "".join(f'<a class="sub" href="#{h}">{html.escape(t)}</a>' for h, t in toc)
        navs.append(f'<details data-sec="{stem}"><summary><a class="top" href="#{stem}">{html.escape(title)}</a></summary>{subs}</details>')
        secs.append(f'<section id="{stem}">{body}</section>')
    return ("<!doctype html><html lang=\"fr\"><head><meta charset=\"utf-8\">"
            "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>Hexis · documentation</title>"
            f"<style>{CSS}</style></head><body><button id=\"menu\">Menu</button>"
            f"<nav><input id=\"q\" type=\"search\" placeholder=\"Rechercher\">{''.join(navs)}</nav>"
            f"<main>{''.join(secs)}</main><script>{JS}</script></body></html>\n")


def comparable(page: str) -> str:
    """The last-commit line moves with every commit, so it never counts as staleness."""
    return re.sub(r"Dernier commit : [^<]*", "Dernier commit", page)


def readme_facts() -> str:
    """English figures for README.md, between its `<!-- facts -->` markers."""
    folders = ["Hexis/App", "Hexis/Theme", "Hexis/Models", "Hexis/Features", "Hexis/Services", "Hexis/Components", "HexisWidgets", "HexisShared"]
    files = [p for sub in folders for p in swift_files(sub)]
    schemas = max(int(m.group(1)) for p in swift_files("Hexis/Models/Schema") if (m := re.search(r"SchemaV(\d+)\.swift$", p)))
    tests = sum(read(p).count("@Test") for p in swift_files("Tools/LogicTests/Tests"))
    life = read(os.path.join(ROOT, "Tools/LogicTests/Tests/LogicTests/Life/LifeTests.swift")).count("@Test")
    rules = sum(1 for l in read(os.path.join(DOCS, "20-regles.md")).splitlines()
                if l.startswith("| ") and not l.startswith(("| Règle", "| Moteur", "| ---")) and not set(l) <= set("|-: "))
    lines = f"{line_count(files):,}".replace(",", " ")
    return (f"- {len(files)} Swift files, {lines} lines, SwiftData schema V{schemas}\n"
            f"- {tests} logic tests, {life} simulated life scenarios\n"
            f"- {rules} documented rules, each with its threshold")


def readme() -> str:
    text = read(os.path.join(ROOT, "README.md"))
    return re.sub(r"<!-- facts -->.*?<!-- /facts -->", lambda m: f"<!-- facts -->\n{readme_facts()}\n<!-- /facts -->", text, flags=re.S)


def main() -> int:
    page = build()
    if "--check" in sys.argv:
        current = read(OUT) if os.path.exists(OUT) else ""
        if comparable(current) != comparable(page) or readme() != read(os.path.join(ROOT, "README.md")):
            print("docs/index.html ou README.md est périmé : lancer python3 Tools/doc.py")
            return 1
        print("doc à jour")
        return 0
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(page)
    refreshed = readme()  # read before the file is opened for writing
    with open(os.path.join(ROOT, "README.md"), "w", encoding="utf-8") as f:
        f.write(refreshed)
    print(f"docs/index.html écrit ({len(page) // 1024} Ko)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
