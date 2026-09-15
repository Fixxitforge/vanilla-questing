#!/usr/bin/env python3
"""Provenance checks: everything this repository points at is something it is
supposed to point at, and nothing in it identifies the tooling that wrote it.

Run from the repository root (run.sh does):

    python3 dev/tests/lint_provenance.py

Every check here is an ALLOWLIST. That is the whole design. A denylist has to
name the thing it is looking for, which means writing that string into the
repository in order to check that the repository does not contain it -- so the
check becomes the leak. An allowlist says what MAY appear, and anything else
fails without ever being named here.

This file excludes itself from the content scans below, because it necessarily
contains the patterns it searches for. It is the one file that is checked by
reading it.
"""
import os, re, subprocess, sys

SELF = "dev/tests/lint_provenance.py"

# This project.
PROJECT_REPO = "Fixxitforge/vanilla-questing"
PROJECT_AUTHOR = "Fixxit"

# Third-party repositories the docs are allowed to cite: the client's own UI
# source, and the AddOns whose behaviour is discussed or was read for reference.
THIRD_PARTY = {
    "Gethe/wow-ui-source",
    "Questie/Questie",
    "seblindfors/Immersion",
    "bloerwald/MapCleaner",
    "Stanzilla/AdvancedInterfaceOptions",
    "ItsJustMeChris/idTip-Community-Fork",
}

# Who may appear as the author or committer of a commit.
IDENTITIES = {
    ("Claude", "noreply@anthropic.com"),
    ("Fixxit", "329487885+Fixxitforge@users.noreply.github.com"),
    # Editing a file through GitHub's web UI commits as GitHub, with the
    # account as the author. Committer, never author.
    ("GitHub", "noreply@github.com"),
}

REPO_REF = re.compile(r"github\.com[/:]([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)")
# A link to a coding session identifies the account that ran it.
SESSION = re.compile(r"claude\.ai/code/session", re.I)
# The repository names the tool, never the model behind it.
MODEL = re.compile(r"\b(Opus|Sonnet|Haiku)\b")

fails = []
def check(ok, label, detail=""):
    if ok:
        print(f"  ok    {label}")
    else:
        fails.append(label)
        print(f"  FAIL  {label}")
        for line in str(detail).splitlines()[:12]:
            print(f"          {line}")

def git(*a):
    r = subprocess.run(["git", *a], capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else ""

def tracked_text_files():
    for path in git("ls-files").split("\n"):
        if not path or path == SELF:
            continue
        try:
            with open(path, encoding="utf-8") as fh:
                yield path, fh.read()
        except (UnicodeDecodeError, OSError):
            continue   # binary, or gone

files = list(tracked_text_files())

# --- 1. every repository this one points at -------------------------------
allowed = THIRD_PARTY | {PROJECT_REPO}
strays = set()
for path, text in files:
    for ref in REPO_REF.findall(text):
        if ref[:-4] if ref.endswith(".git") else ref:
            slug = ref[:-4] if ref.endswith(".git") else ref
            if slug not in allowed:
                strays.add(f"{path}: {slug}")
check(not strays, "every GitHub reference is this repo or an allowed third party",
      "\n".join(sorted(strays)))

# --- 2. no session links --------------------------------------------------
hits = [p for p, t in files if SESSION.search(t)]
check(not hits, "no agent session links in tracked files", "\n".join(hits))

msgs = git("log", "--all", "--format=%B")
check(not SESSION.search(msgs), "no agent session links in commit messages")

# --- 3. no model identifiers ---------------------------------------------
hits = [f"{p}: {MODEL.search(t).group(0)}" for p, t in files if MODEL.search(t)]
check(not hits, "no model identifiers in tracked files", "\n".join(hits))
check(not MODEL.search(msgs), "no model identifiers in commit messages")

# --- 4. authorship --------------------------------------------------------
shallow = git("rev-parse", "--is-shallow-repository").strip() == "true"
people = {tuple(l.split("\t")) for l in
          git("log", "--all", "--format=%an\t%ae%n%cn\t%ce").split("\n") if "\t" in l}
unknown = {f"{n} <{e}>" for n, e in people if (n, e) not in IDENTITIES}
if shallow and not people:
    print("  note  shallow clone -- authorship not checked")
else:
    check(not unknown, "every commit author and committer is known",
          "\n".join(sorted(unknown)))

# --- 5. the shipped files name the author --------------------------------
toc = "VanillaQuesting/VanillaQuesting.toc"
check(os.path.exists(toc) and f"## Author: {PROJECT_AUTHOR}" in open(toc, encoding="utf-8").read(),
      "the .toc names the author")
check(os.path.exists("LICENSE") and PROJECT_AUTHOR in open("LICENSE", encoding="utf-8").read(),
      "LICENSE names the author")

sys.exit(1 if fails else 0)
