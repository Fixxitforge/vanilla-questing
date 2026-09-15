#!/usr/bin/env python3
"""Repository hygiene. Links point where they should, and nothing ships in a
public repository that has no business being there.

Run from the repository root, which is what run.sh does:

    python3 dev/tests/lint_hygiene.py [-v]

Quiet unless something fails; -v lists every check.

Each check is a list of what is ALLOWED rather than a list of what is wrong.
A check that only knows today's mistakes goes green the first time a new one
appears, and anything added to this file has to be added on purpose.

The content scans skip this file, since it holds the patterns they search for.
"""
import os, re, subprocess, sys

SELF = "dev/tests/lint_hygiene.py"
VERBOSE = "-v" in sys.argv

# Repositories the docs may cite: the client's own UI source, and the AddOns
# whose behaviour is discussed or was read for reference. Anything outside this
# set is a typo or a stale link, and sends a reader somewhere wrong.
THIS_REPO = "Fixxitforge/vanilla-questing"
THIRD_PARTY = {
    "Gethe/wow-ui-source",
    "Questie/Questie",
    "seblindfors/Immersion",
    "bloerwald/MapCleaner",
    "Stanzilla/AdvancedInterfaceOptions",
    "ItsJustMeChris/idTip-Community-Fork",
}

# Who may appear as the author or committer of a commit. Catches a commit made
# with a misconfigured user.email, which is easy to do and a nuisance to correct
# once it has been pushed.
IDENTITIES = {
    ("Claude", "noreply@anthropic.com"),
    ("Fixxit", "329487885+Fixxitforge@users.noreply.github.com"),
    # The same person, from a GitHub account with email privacy switched off:
    # a web-UI commit then carries the real address as the author. Six of them
    # are in the history already, so this entry has to stay whether or not the
    # setting is ever changed -- `git log --all` never forgets.
    ("Fixxit", "fixxitforge@gmail.com"),
    # Editing a file through GitHub's web UI commits as GitHub, with the
    # account as the author. Committer, never author.
    ("GitHub", "noreply@github.com"),
}

AUTHOR = "Fixxit"

REPO_REF = re.compile(r"github\.com[/:]([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)")
# A coding-session link only opens for the account that ran the session, so in
# a public repository it is a dead link with a session id sitting in it.
SESSION = re.compile(r"claude\.ai/code/session", re.I)
# AGENT.md: the repository names the tool, never the model behind it.
MODEL = re.compile(r"\b(Opus|Sonnet|Haiku)\b")

fails = []
def check(ok, label, detail=""):
    if not ok:
        fails.append(label)
        print(f"  FAIL  {label}")
        for line in str(detail).splitlines()[:12]:
            print(f"          {line}")
    elif VERBOSE:
        print(f"  ok    {label}")

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
msgs = git("log", "--all", "--format=%B")

strays = set()
for path, text in files:
    for ref in REPO_REF.findall(text):
        slug = ref[:-4] if ref.endswith(".git") else ref
        if slug != THIS_REPO and slug not in THIRD_PARTY:
            strays.add(f"{path}: {slug}")
check(not strays, "every GitHub link is this repo or a cited third party",
      "\n".join(sorted(strays)))

hits = [p for p, t in files if SESSION.search(t)]
check(not hits, "no coding-session links in tracked files", "\n".join(hits))
check(not SESSION.search(msgs), "no coding-session links in commit messages")

hits = [f"{p}: {MODEL.search(t).group(0)}" for p, t in files if MODEL.search(t)]
check(not hits, "no model identifiers in tracked files", "\n".join(hits))
check(not MODEL.search(msgs), "no model identifiers in commit messages")

people = {tuple(l.split("\t")) for l in
          git("log", "--all", "--format=%an\t%ae%n%cn\t%ce").split("\n") if "\t" in l}
unknown = {f"{n} <{e}>" for n, e in people if (n, e) not in IDENTITIES}
if not people and git("rev-parse", "--is-shallow-repository").strip() == "true":
    print("  note  shallow clone -- commit identities not checked")
else:
    check(not unknown, "every commit author and committer is known",
          "\n".join(sorted(unknown)))

toc = "VanillaQuesting/VanillaQuesting.toc"
check(os.path.exists(toc) and f"## Author: {AUTHOR}" in open(toc, encoding="utf-8").read(),
      "the .toc names the author")
check(os.path.exists("LICENSE") and AUTHOR in open("LICENSE", encoding="utf-8").read(),
      "LICENSE names the author")

sys.exit(1 if fails else 0)
