#!/usr/bin/env bash
# Secret scanning hook - checks for AKIA patterns and tokens
input=$(cat)
if echo "$input" | grep -qP 'AKIA[0-9A-Z]{16}'; then
  echo "BLOCKED: AWS key detected"
  exit 1
fi
