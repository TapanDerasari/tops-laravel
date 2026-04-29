#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURES=("clean" "dirty")
FAIL=0

for name in "${FIXTURES[@]}"; do
    expected="$PLUGIN_DIR/tests/fixtures/$name/expected.json"
    if [[ ! -f "$expected" ]]; then
        echo "[$name] SKIP — no expected.json"
        continue
    fi

    echo "[$name] running reviewer..."
    out="$(claude --plugin-dir "$PLUGIN_DIR" -p "/tops-laravel:review fixture:$name" 2>&1)"

    result_line="$(grep -oE '__FIXTURE_RESULT__ \{[^}]*\}' <<< "$out" | tail -1 | sed 's/^__FIXTURE_RESULT__ //' || true)"
    if [[ -z "$result_line" ]]; then
        result_line="$(grep -oE '\{"verdict":"[^"]+","critical":[0-9]+,"important":[0-9]+,"minor":[0-9]+\}' <<< "$out" | tail -1 || true)"
    fi
    if [[ -z "$result_line" ]]; then
        v_raw="$(grep -m1 -oE '\*\*Verdict:\*\* [^_]*' <<< "$out" | head -1 | sed -E 's/.*\*\*Verdict:\*\* //; s/\*+//g; s/[[:space:]]+$//' || true)"
        counts_raw="$(grep -m1 -oE '\*\*Issues Found:\*\* [0-9]+ critical, [0-9]+ important, [0-9]+ minor' <<< "$out" || true)"
        if [[ -n "$v_raw" && -n "$counts_raw" ]]; then
            c_n="$(grep -oE '[0-9]+ critical' <<< "$counts_raw" | grep -oE '[0-9]+')"
            i_n="$(grep -oE '[0-9]+ important' <<< "$counts_raw" | grep -oE '[0-9]+')"
            m_n="$(grep -oE '[0-9]+ minor' <<< "$counts_raw" | grep -oE '[0-9]+')"
            result_line="{\"verdict\":\"${v_raw}\",\"critical\":${c_n},\"important\":${i_n},\"minor\":${m_n}}"
        fi
    fi
    if [[ -z "$result_line" ]]; then
        echo "[$name] FAIL — could not extract result (no __FIXTURE_RESULT__ line, no bare JSON, no parseable Verdict+Issues Found lines)"
        echo "$out" | tail -40
        FAIL=1; continue
    fi

    verdict="$(echo "$result_line" | jq -r '.verdict')"
    critical="$(echo "$result_line" | jq -r '.critical')"
    important="$(echo "$result_line" | jq -r '.important')"
    minor="$(echo "$result_line" | jq -r '.minor')"

    exp_verdict="$(jq -r '.verdict' "$expected")"
    min_c="$(jq -r '.min_critical' "$expected")"; max_c="$(jq -r '.max_critical' "$expected")"
    min_i="$(jq -r '.min_important' "$expected")"; max_i="$(jq -r '.max_important' "$expected")"
    min_m="$(jq -r '.min_minor' "$expected")"; max_m="$(jq -r '.max_minor' "$expected")"

    pass=1
    [[ "$verdict" == "$exp_verdict" ]] || { echo "[$name] verdict mismatch: got $verdict, want $exp_verdict"; pass=0; }
    (( critical >= min_c && critical <= max_c )) || { echo "[$name] critical=$critical not in [$min_c,$max_c]"; pass=0; }
    (( important >= min_i && important <= max_i )) || { echo "[$name] important=$important not in [$min_i,$max_i]"; pass=0; }
    (( minor >= min_m && minor <= max_m )) || { echo "[$name] minor=$minor not in [$min_m,$max_m]"; pass=0; }

    while IFS= read -r needle; do
        [[ -z "$needle" ]] && continue
        match=0
        IFS='|' read -ra alts <<< "$needle"
        for a in "${alts[@]}"; do
            grep -qF -- "$a" <<< "$out" && { match=1; break; }
        done
        (( match )) || { echo "[$name] missing required substring (any of): $needle"; pass=0; }
    done < <(jq -r '.must_contain_substrings[]' "$expected")

    while IFS= read -r needle; do
        [[ -z "$needle" ]] && continue
        if grep -qF -- "$needle" <<< "$out"; then
            echo "[$name] forbidden substring present: $needle"; pass=0
        fi
    done < <(jq -r '.must_not_contain_substrings[]' "$expected")

    (( pass )) && echo "[$name] PASS" || { echo "[$name] FAIL"; FAIL=1; }
done

exit "$FAIL"
