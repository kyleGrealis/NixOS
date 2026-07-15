#!/usr/bin/env bash
PI5_NAME="nixPi5"
echo "🛡️ Switching to protection mode..."
sudo tailscale up --exit-node="$PI5_NAME"

STATUS=$(tailscale status)
if echo "$STATUS" | grep -q "; exit node;"; then
  echo "⚠️ -------------------- WARNING!! ---------------------"
  echo "✅ Exit node protection ENABLED!! All traffic now routes through your Tailnet."
  echo "⚠️ ----------------------------------------------------"
else
  echo "❌ Something went wrong. Please check tailscale status."
fi
