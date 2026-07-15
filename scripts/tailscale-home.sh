#!/usr/bin/env bash
echo "🏠 Switching to home mode..."
sudo tailscale up --exit-node=""

STATUS=$(tailscale status)
if echo "$STATUS" | grep -q "offers exit node"; then
  echo "✅ Exit node protection disabled! Traffic now routes normally."
else
  echo "❌ Something went wrong. Please check tailscale status."
fi
