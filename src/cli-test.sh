#!/usr/bin/env bash
set -u

CLI="src/cli.ts"
RATES="exchange-rates.json"

PASS=0
FAIL=0

# Helper: pretty output
ok()   { echo "✅ $1"; PASS=$((PASS+1)); }
bad()  { echo "❌ $1"; echo "   -> $2"; FAIL=$((FAIL+1)); }

# Helper: run CLI and compare expected output
run_test() {
  local name="$1"
  local from="$2"
  local to="$3"
  local amount="$4"
  local expected="$5"

  # CLI ausführen
  output=$(deno run --quiet --allow-read "$CLI" --rates "$RATES" --from "$from" --to "$to" --amount "$amount" 2>&1)
  code=$?

  if [ $code -ne 0 ]; then
    bad "$name" "Exit Code war $code (Output: $output)"
    return
  fi

  # Output trimmen (nur Zahl erwartet)
  output="$(echo "$output" | tr -d '\r' | tail -n 1)"

  if [ "$output" = "$expected" ]; then
    ok "$name"
  else
    bad "$name" "Expected: '$expected' | Got: '$output'"
  fi
}

echo "=== CLI Tests starten ==="

# ---------
# 1) Konversion mit bekannter Waehrung
# Beispiel aus README: 1900 CHF -> USD = 2345.679012345679
run_test "Test 1: CHF -> USD (1900)" "chf" "usd" "1900" "2345.679012345679"

# 2) Umgekehrt (Reverse-Rate)
# Wenn 1 CHF = 1.2345679012345678 USD, dann 1900 USD = 1539 CHF
# (1900 / 1.2345679012345678 = 1539 exakt)
run_test "Test 2: USD -> CHF (1900) reverse" "usd" "chf" "1900" "1539"

# 3) Bekannte Rate aus exchange-rates.json: USD -> CHF 0.81 (aus README)
# 100 USD -> CHF = 81
run_test "Test 3: USD -> CHF (100)" "usd" "chf" "100" "81"

# 4) Umgekehrt: CHF -> USD mit 0.81 (reverse)
# 81 CHF -> USD = 100
run_test "Test 4: CHF -> USD (81) reverse" "chf" "usd" "81" "100"

echo "=== Resultat: PASS=$PASS | FAIL=$FAIL ==="

if [ $FAIL -eq 0 ]; then
  exit 0
else
  exit 1
fi
