#!/usr/bin/env bash
# usage: ./kie-img.sh "<prompt>" [model] [aspect] [reso]
set -euo pipefail
BASE="https://api.kie.ai/api/v1/jobs"
prompt="$1"; model="${2:-gpt-image-2-5-flare-text-to-image}"; aspect="${3:-1:1}"; reso="${4:-2K}"
body=$(python3 -c 'import json,sys;print(json.dumps({"model":sys.argv[2],"input":{"prompt":sys.argv[1],"aspect_ratio":sys.argv[3],"resolution":sys.argv[4],"output_format":"png"}}))' "$prompt" "$model" "$aspect" "$reso")
tid=$(curl -s -X POST "$BASE/createTask" -H "Authorization: Bearer $KIE_API_KEY" -H "Content-Type: application/json" -d "$body" \
  | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("data",{}).get("taskId") or "ERR "+json.dumps(d))')
case "$tid" in ERR*) echo "$tid" >&2; exit 1;; esac
echo "taskId=$tid" >&2
for i in $(seq 1 75); do
  r=$(curl -s "$BASE/recordInfo?taskId=$tid" -H "Authorization: Bearer $KIE_API_KEY")
  st=$(printf '%s' "$r" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("data",{}).get("state",""))' 2>/dev/null || echo)
  [ "$st" = "success" ] && { printf '%s' "$r" | python3 -c 'import sys,json;d=json.load(sys.stdin)["data"];print(json.loads(d["resultJson"])["resultUrls"][0])'; exit 0; }
  [ "$st" = "fail" ] && { printf '%s' "$r" | python3 -c 'import sys,json;d=json.load(sys.stdin)["data"];print("FAIL:",d.get("failMsg") or d.get("failCode"))' >&2; exit 1; }
  sleep 4
done
echo "TIMEOUT" >&2; exit 1
