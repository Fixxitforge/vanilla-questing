#!/bin/sh
# Run every scenario. Needs lua5.1 -- the client's Lua version, so the same
# forward-reference and scoping rules apply here as in game.
#
#   cd dev/tests && ./run.sh        quiet: failures and the totals only
#   cd dev/tests && ./run.sh -v     every check, passing ones included
#
# Quiet by default because a passing run has one useful line in it, and a
# failing one gets buried when thirty green lines scroll past with it.
cd "$(dirname "$0")" || exit 1

verbose=0
[ "${1:-}" = "-v" ] && verbose=1
# Passing progress. Printed only with -v; failures never go through this.
say() { [ "$verbose" -eq 1 ] && printf '%s\n' "$1"; return 0; }

SCENARIOS="normal no_settings settings_refuses cvar_refused tracking_refused tracking_slow
           no_cminimap no_entry no_cvar native native_halfway no_tooltipfunc
           no_template no_button_type outline_off outline_late_off vars_late_on"

total=0
failed=0

# Static checks first. These catch things the scenarios cannot: a call to a
# file-local function declared further down resolves as a nil global, which
# `luac -p` accepts and every scenario passes right over.
lintfail=0
fwdout=$( cd ../.. && python3 dev/tests/lint_forward_refs.py \
    "VanillaQuesting/*.lua" "dev/UnmarkedRecon/*.lua" \
    "dev/knowledge/*.lua" 2>&1 ) || lintfail=1
if [ "$lintfail" -ne 0 ]; then printf '%s\n' "$fwdout"; else say "$fwdout"; fi

# Links point where they should, no coding-session links or model identifiers
# ship, and every commit author is one we know. It runs here rather than by eye
# because that is the only way any of it keeps being true.
hygargs=""
[ "$verbose" -eq 1 ] && hygargs="-v"
( cd ../.. && python3 dev/tests/lint_hygiene.py $hygargs ) || lintfail=1

# luacheck: unused and shadowed locals, undefined globals, assignments nobody
# reads. Added for #37, from the Questie audit -- it would have caught the
# duplicate `local applyingPreset` (#22) as a shadowed variable, where it took
# a human reading an audit.
#
# It found four things on the first run it was pointed at: `C` standing for
# both the colour table and C_Minimap in one file, a `nativeCategory` assigned
# and never read, a `sawWhiteBody` guard that was collected and never asserted,
# and `ClassicQuestingMoPDB = nil` -- the SavedVariables name from before the
# rename, doing nothing in a test that was passing for a reason it did not
# state.
#
# Config in .luacheckrc, and the WoW globals are an explicit ALLOWLIST rather
# than a blanket ignore: on a client where the usual assumptions do not hold, a
# name that looks right and is not is exactly the mistake worth catching.
if command -v luacheck >/dev/null 2>&1; then
    lcout=$( cd ../.. && luacheck . --no-color --codes 2>&1 )
    if [ $? -eq 0 ]; then
        say 'luacheck       ok'
    else
        lintfail=1
        printf '%s\n' "$lcout"
    fi
else
    # Not a skip. A run that never asked luacheck anything has not passed it,
    # and "0 failed" at the foot of such a run was a claim nobody had checked.
    lintfail=1
    printf 'luacheck       NOT INSTALLED -- a skipped check is not a pass (apt-get install lua-check)\n'
fi

# And the probe has to at least compile. It is not covered by any scenario --
# it never loads here -- so a syntax error in it would otherwise reach the
# client before it reached this suite.
for f in ../../VanillaQuesting/*.lua ../../dev/UnmarkedRecon/*.lua \
         ../../dev/knowledge/*.lua; do
    luac5.1 -p "$f" || lintfail=1
done

# XML too, where there is any. The client is far less forgiving than it looks:
# a "--" inside an XML comment is illegal and silently costs you the whole
# file, which is a whole round trip to discover in game.
for f in ../../VanillaQuesting/*.xml ../../dev/UnmarkedRecon/*.xml; do
    [ -e "$f" ] || continue
    python3 -c "import sys,xml.dom.minidom; xml.dom.minidom.parse(sys.argv[1])" "$f" \
        || { echo "  [XML] $f is not well-formed"; lintfail=1; }
done
[ "$lintfail" -eq 0 ] && say 'compiles       ok'

# The probe runs too. It is not covered by any scenario -- it never loads in
# them -- and it has cost two wasted round trips by shipping in a state where
# it produced nothing at all. This does not check what it FINDS, which lives
# in the client; it checks that it RUNS, which is the part that failed.
# By exit status as well as by what it printed. A smoke test that dies with a
# Lua error prints no [FAIL] line at all -- only the interpreter's -- and
# grepping for [FAIL] alone read that as a pass.
smoke=$(lua5.1 recon_smoke.lua 2>&1); smokerc=$?
if [ "$smokerc" -ne 0 ] || printf '%s\n' "$smoke" | grep -q '\[FAIL\]'; then
    lintfail=1
    printf 'probe runs     FAILED\n'
    printf '%s\n' "$smoke" | grep '\[FAIL\]\|lua5.1:'
else
    say 'probe runs     ok'
fi
say ''
for s in $SCENARIOS; do
    out=$(lua5.1 run_tests.lua "$s" 2>&1); rc=$?
    ok=$(printf '%s\n' "$out" | grep -c '\[ok\]')
    bad=$(printf '%s\n' "$out" | grep -c '\[FAIL\]')
    # A scenario that dies part-way prints no [FAIL] line: the interpreter
    # stops it, and every check after the error simply never runs. Counting
    # [FAIL] lines alone turned that into "0 failed" -- every scenario could
    # crash at its first line and the run still passed. So a scenario also
    # has to exit cleanly AND reach its own closing summary line.
    if [ "$rc" -ne 0 ] && [ "$bad" -eq 0 ] ||
       ! printf '%s\n' "$out" | grep -q "^--- $s: [0-9]* passed"; then
        bad=$((bad + 1))
        out=$(printf '%s\n  [FAIL] %s did not run to the end (exit %s)' "$out" "$s" "$rc")
    fi
    total=$((total + ok))
    failed=$((failed + bad))
    if [ "$verbose" -eq 1 ] || [ "$bad" -ne 0 ]; then
        printf '%-18s %3d ok  %d fail\n' "$s" "$ok" "$bad"
    fi
    printf '%s\n' "$out" | grep '\[FAIL\]\|lua5.1:'
done
printf '%d checks, %d failed\n' "$total" "$failed"
# Said again at the end. A static failure scrolls off the top while "0 failed"
# sits at the bottom looking like a pass.
[ "$lintfail" -eq 0 ] || printf 'STATIC CHECKS FAILED -- see the top of this output\n'
[ "$failed" -eq 0 ] && [ "$lintfail" -eq 0 ] || exit 1
