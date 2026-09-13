# Knowledge

Reference material for developing this AddOn: what the client actually exposes, how other people
solved the same problems, and what a port to another client would have to deal with.

This is not documentation of this AddOn — that is `SPEC.md`. It is the notebook behind it.

| | |
| --- | --- |
| [`CLIENT-SOURCE.md`](CLIENT-SOURCE.md) | **Start here.** Blizzard's own interface source for build 5.5.4.69585, how to fetch it, which file each flavour really loads, and the things reading it settled |
| [`api-index.txt`](api-index.txt) | Every system, function and event the client documents. 533 systems, 4,590 functions, 1,483 events |
| [`api-signatures.txt`](api-signatures.txt) | Full signatures and structures, for the systems this AddOn touches |
| [`api-compat.txt`](api-compat.txt) | Which of 7,362 API functions exist on Classic Era, TBC, **Mists** and retail, with protection tags. From the wiki; fills two gaps Blizzard's own documentation has |
| [`REFERENCE-ADDONS.md`](REFERENCE-ADDONS.md) | Six AddOns worth reading, what to take from each, and what not to copy |
| [`RETAIL.md`](RETAIL.md) | What a retail port would have to remove. All of it unverified, and marked as such |
| `fetch_client_source.sh` | Clones a client's interface source and rebuilds the index |
| `build_api_index.lua` | Generates the two index files from the client's own API documentation |
| `build_wiki_compat.py` | Generates `api-compat.txt` from the wiki's two API pages |

## The rule this is here to serve

Two answers to "what does this client do" are allowed: **the source says so**, with a file and a
line, or **the game said so**, with a probe and a log. Memory is not a third answer. The rule
predates this directory; what this directory changes is that the first of the two is now a clone
away instead of a round trip through someone's evening.

Where the two disagree, the game wins and the disagreement gets written down.

## Rebuilding after a patch

```sh
dev/knowledge/fetch_client_source.sh              # classic, the progression client
dev/knowledge/fetch_client_source.sh live         # retail
```

The script fetches the source, prints the build it got, and regenerates `api-index.txt` and
`api-signatures.txt` in place. Commit the regenerated files with the interface bump, so the index
in the repository always describes the client in the `.toc`.

## The wiki

<https://warcraft.wiki.gg/wiki/World_of_Warcraft_API> and
<https://warcraft.wiki.gg/wiki/World_of_Warcraft_API/Classic>.

Both were unreachable when this directory was first written, and the note here said so. They are
reachable now, and reading them changed the picture: the wiki is not a worse copy of Blizzard's
documentation, it is a **complement**, because it carries two things the generated tables do not.

**1. The old global functions.** Blizzard's generated documentation covers the `C_*` systems and
nothing else. `GetQuestLogTitle`, `GetNumQuestLogEntries` and `AddQuestWatch` are not in it at all
— and this client is full of them:

```
ETM.  GetQuestLogTitle
ETM.  AddQuestWatch
...X  C_QuestLog.AddQuestWatch
```

The old ones exist on Era, TBC and Mists and are gone from retail; the `C_QuestLog` replacement
exists only on retail. That one pair is a large part of what a retail port means, and
`api-index.txt` alone cannot show it.

**2. Protection.** `{{apitag|...}}` marks functions as `protected` (133), `nocombat` (27),
`hwevent` (23), `framexml` (14), plus `noscript`, `deprecated`, `noinstance` and `grouponly`.
Nothing in Blizzard's generated tables says any of this.

That qualifies a claim made elsewhere in this directory. *Only the game says whether a call is
protected* is too strong: the wiki says so too, for many calls, and it is worth reading before
spending a probe. What stays true is that the wiki is **community-maintained and its tag list
tracks retail**, so a tag is corroboration for a 5.5.4 question and never proof.

An example of exactly that trap, caught while writing this: `C_Map.OpenWorldMap` is tagged
`nocombat`, which looks like the answer to this project's world-map-in-combat problem. It is not.
The compatibility table says `...X` — the function is **retail-only and does not exist on 5.5.4**.
Useful for the port; irrelevant to the bug it appeared to explain.

### What the wiki has little to say about

Cross-referencing the 72 API calls this AddOn makes against the table matched four of them. The
rest are FrameXML — `WatchFrame_Update`, `QuestMapFrame_UpdateAll`, `WATCHFRAME_LINKBUTTONS` —
which the wiki's API list does not cover, because they are not API functions. **This project lives
mostly in FrameXML**, which is why Blizzard's source drop matters more here than the wiki does, and
why the two are kept side by side rather than one being picked.

### Which source wins

1. **Blizzard's source and generated documentation**, for this exact build. Exact, and it is the
   code the client runs.
2. **The wiki**, for what the above does not carry: the old globals, protection tags,
   cross-flavour availability, and prose about what a function is *for*.
3. **A probe in the game**, for anything either of them cannot settle — whether a write is
   accepted, what taints, what renders — and for any case where 1 and 2 disagree.

Memory is still not on the list.
