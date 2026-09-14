#!/bin/sh
# Run every scenario. Needs lua5.1 -- the client's Lua version, so the same
# forward-reference and scoping rules apply here as in game.
#
#   cd dev/tests && ./run.sh
cd "$(dirname "$0")" || exit 1

SCENARIOS="normal no_settings settings_refuses cvar_refused tracking_refused tracking_slow
           no_cminimap no_entry no_cvar native native_halfway no_tooltipfunc
           no_template no_button_type outline_off outline_late_off vars_late_on"

total=0
failed=0

# Static checks first. These catch things the scenarios cannot: a call to a
# file-local function declared further down resolves as a nil global, which
# `luac -p` accepts and every scenario passes right over.
lintfail=0
( cd ../.. && python3 dev/tests/lint_forward_refs.py \
    "VanillaQuesting/*.lua" "dev/UnmarkedRecon/*.lua" \
    "dev/knowledge/*.lua" ) || lintfail=1

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
[ "$lintfail" -eq 0 ] && printf 'compiles       ok\n'

# The probe runs too. It is not covered by any scenario -- it never loads in
# them -- and it has cost two wasted round trips by shipping in a state where
# it produced nothing at all. This does not check what it FINDS, which lives
# in the client; it checks that it RUNS, which is the part that failed.
smoke=$(lua5.1 recon_smoke.lua 2>&1)
if printf '%s\n' "$smoke" | grep -q '\[FAIL\]'; then
    lintfail=1
    printf 'probe runs     FAILED\n'
    printf '%s\n' "$smoke" | grep '\[FAIL\]\|lua5.1:'
else
    printf 'probe runs     ok\n'
fi
printf '\n'
for s in $SCENARIOS; do
    out=$(lua5.1 run_tests.lua "$s" 2>&1)
    ok=$(printf '%s\n' "$out" | grep -c '\[ok\]')
    bad=$(printf '%s\n' "$out" | grep -c '\[FAIL\]')
    total=$((total + ok))
    failed=$((failed + bad))
    printf '%-18s %3d ok  %d fail\n' "$s" "$ok" "$bad"
    printf '%s\n' "$out" | grep '\[FAIL\]\|lua5.1:'
done
printf '\n%d checks, %d failed\n' "$total" "$failed"
# Said again at the end. A static failure scrolls off the top while "0 failed"
# sits at the bottom looking like a pass.
[ "$lintfail" -eq 0 ] || printf 'STATIC CHECKS FAILED -- see the top of this output\n'
[ "$failed" -eq 0 ] && [ "$lintfail" -eq 0 ] || exit 1
