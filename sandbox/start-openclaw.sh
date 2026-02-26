#!/bin/bash
set -e

if [ "$1" = "list" ]; then
  curl -s http://host.docker.internal:1234/v1/models | python3 -c "
import json, sys
data = json.load(sys.stdin).get('data', [])
for m in data: print(m['id'])
"
  exit 0
fi

MODEL=${1:-"openai/gpt-oss-20b"}

if [ -n "$1" ]; then
  python3 -c "
import json
p = '$HOME/.openclaw/openclaw.json'
with open(p) as f: cfg = json.load(f)
cfg['agents']['defaults']['model'] = {'primary': 'lmstudio/$MODEL'}
with open(p, 'w') as f: json.dump(cfg, f, indent=2)
"
fi

bun run ~/model-runner-bridge.ts &
BRIDGE_PID=$!
sleep 1

unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy

openclaw

kill $BRIDGE_PID 2>/dev/null || true
