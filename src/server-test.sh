#!/usr/bin/env bash
set -u

SERVER="server.ts"

PASS=0
FAIL=0

ok()  { echo "✅ $1"; PASS=$((PASS+1)); }
bad() { echo "❌ $1"; echo "   -> $2"; FAIL=$((FAIL+1)); }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Fehlt: $1"; exit 1; }
}

need_cmd deno
need_cmd curl
need_cmd jq

# --------- Port aus server.ts best effort lesen (fallback 8000)
PORT="$(grep -Eo 'port[^0-9]*[0-9]+' "$SERVER" 2>/dev/null | grep -Eo '[0-9]+' | head -n 1 || true)"
PORT="${PORT:-8000}"
BASE="http://127.0.0.1:${PORT}"

# --------- Server starten
deno run --quiet --allow-net --allow-read --allow-write "$SERVER" >/tmp/server-test.log 2>&1 &
SERVER_PID=$!

cleanup() {
  # Server beenden
  if kill -0 "$SERVER_PID" >/dev/null 2>&1; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    # kurz warten, dann notfalls hart
    for _ in 1 2 3 4 5; do
      kill -0 "$SERVER_PID" >/dev/null 2>&1 || break
      sleep 0.1
    done
    kill -9 "$SERVER_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

# --------- Warten bis Server erreichbar
wait_ready() {
  for _ in $(seq 1 60); do
    # probiere ein paar typische endpoints zum "ready" check
    if curl -sS -m 0.5 "$BASE/" >/dev/null 2>&1; then return 0; fi
    if curl -sS -m 0.5 "$BASE/health" >/dev/null 2>&1; then return 0; fi
    if curl -sS -m 0.5 "$BASE/rates" >/dev/null 2>&1; then return 0; fi
    sleep 0.1
  done
  return 1
}

if wait_ready; then
  ok "Server gestartet (PORT=$PORT)"
else
  bad "Server gestartet" "Server nicht erreichbar unter $BASE (siehe /tmp/server-test.log)"
  exit 1
fi

# --------- Helpers (HTTP + JSON parsing)
http_code() {
  # curl args...
  curl -sS -o /tmp/server-test.body -w "%{http_code}" "$@"
}

extract_rate() {
  # versucht aus Body einen Kurs rauszuholen:
  # - { "rate": 1.23 }
  # - { "value": 1.23 }
  # - 1.23
  jq -r '
    if type=="object" then
      (.rate // .value // .exchangeRate // .result // empty)
    elif type=="number" then
      .
    else
      empty
    end
  ' /tmp/server-test.body 2>/dev/null | head -n 1
}

# --------- Kandidaten fuer Endpunkte
# SET: POST/PUT
try_set_rate() {
  local from="$1" to="$2" rate="$3"
  local bodyA bodyB
  bodyA="$(jq -n --arg f "$from" --arg t "$to" --argjson r "$rate" '{from:$f,to:$t,rate:$r}')"
  bodyB="$(jq -n --argjson r "$rate" '{rate:$r}')"

  local endpoints=(
    # Query style
    "/rates?from=$from&to=$to"
    "/rate?from=$from&to=$to"
    # Path style
    "/rates/$from/$to"
    "/rate/$from/$to"
    "/exchange-rates/$from/$to"
    "/exchange-rate/$from/$to"
    # Collection style
    "/rates"
    "/rate"
    "/exchange-rates"
    "/exchange-rate"
  )

  for ep in "${endpoints[@]}"; do
    # PUT mit bodyA
    code="$(http_code -X PUT -H "Content-Type: application/json" -d "$bodyA" "$BASE$ep" || true)"
    if [[ "$code" =~ ^2 ]]; then return 0; fi

    # POST mit bodyA
    code="$(http_code -X POST -H "Content-Type: application/json" -d "$bodyA" "$BASE$ep" || true)"
    if [[ "$code" =~ ^2 ]]; then return 0; fi

    # PUT mit bodyB (nur rate)
    code="$(http_code -X PUT -H "Content-Type: application/json" -d "$bodyB" "$BASE$ep" || true)"
    if [[ "$code" =~ ^2 ]]; then return 0; fi

    # POST mit bodyB (nur rate)
    code="$(http_code -X POST -H "Content-Type: application/json" -d "$bodyB" "$BASE$ep" || true)"
    if [[ "$code" =~ ^2 ]]; then return 0; fi
  done

  return 1
}

# GET
try_get_rate() {
  local from="$1" to="$2"
  local endpoints=(
    "/rates/$from/$to"
    "/rate/$from/$to"
    "/exchange-rates/$from/$to"
    "/exchange-rate/$from/$to"
    "/rates?from=$from&to=$to"
    "/rate?from=$from&to=$to"
  )

  for ep in "${endpoints[@]}"; do
    code="$(http_code -X GET "$BASE$ep" || true)"
    if [[ "$code" =~ ^2 ]]; then
      r="$(extract_rate || true)"
      if [ -n "${r:-}" ]; then
        echo "$r"
        return 0
      fi
      # wenn response kein rate feld hat, trotzdem als "ok" behandeln und body zurueckgeben
      cat /tmp/server-test.body
      return 0
    fi
  done
  return 1
}

# DELETE
try_delete_rate() {
  local from="$1" to="$2"
  local endpoints=(
    "/rates/$from/$to"
    "/rate/$from/$to"
    "/exchange-rates/$from/$to"
    "/exchange-rate/$from/$to"
    "/rates?from=$from&to=$to"
    "/rate?from=$from&to=$to"
  )

  for ep in "${endpoints[@]}"; do
    code="$(http_code -X DELETE "$BASE$ep" || true)"
    if [[ "$code" =~ ^2 ]]; then return 0; fi
  done
  return 1
}

# --------- Tests
echo "=== Server Tests starten ==="

# Wir nutzen absichtlich ein eigenes Paar, um nichts zu ueberschreiben
FROM="tst"
TO="abc"
RATE="1.23"

# 1) Hinterlegen
if try_set_rate "$FROM" "$TO" "$RATE"; then
  ok "Test 1: neuen Wechselkurs hinterlegt ($FROM -> $TO = $RATE)"
else
  bad "Test 1: neuen Wechselkurs hinterlegt" "Kein passender SET-Endpunkt gefunden. Log: /tmp/server-test.log"
fi

# 2) Abrufen bekannt (muss unseren gesetzten Kurs liefern)
got="$(try_get_rate "$FROM" "$TO" || true)"
if [ -n "${got:-}" ] && [ "$got" = "$RATE" ]; then
  ok "Test 2: bekannten Wechselkurs abgerufen ($FROM -> $TO = $got)"
else
  bad "Test 2: bekannten Wechselkurs abgerufen" "Expected '$RATE', got '${got:-<leer>}'"
fi

# 3) Abrufen unbekannt (Negativtest) -> muss fehlschlagen (nicht 2xx)
UNKNOWN_FROM="zzz"
UNKNOWN_TO="yyy"
if try_get_rate "$UNKNOWN_FROM" "$UNKNOWN_TO" >/dev/null 2>&1; then
  bad "Test 3: unbekannten Wechselkurs (Negativtest)" "Server lieferte trotzdem einen Wert"
else
  ok "Test 3: unbekannten Wechselkurs (Negativtest)"
fi

# 4) Entfernen
if try_delete_rate "$FROM" "$TO"; then
  ok "Test 4: Wechselkurs entfernt ($FROM -> $TO)"
else
  bad "Test 4: Wechselkurs entfernt" "Kein passender DELETE-Endpunkt gefunden"
fi

# Nach Delete sollte er wieder unbekannt sein
if try_get_rate "$FROM" "$TO" >/dev/null 2>&1; then
  bad "Nachtest: Kurs nach Delete nicht mehr vorhanden" "Server liefert noch Daten"
else
  ok "Nachtest: Kurs nach Delete nicht mehr vorhanden"
fi

echo "=== Resultat: PASS=$PASS | FAIL=$FAIL ==="

if [ "$FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
