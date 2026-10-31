#!/usr/bin/env python3
"""Status line: model, context size, the real Pro limits (5 h session and week) and a warning when the prompt cache is cold.

Claude Code sends everything needed: context_window.used_percentage (1M window), rate_limits.five_hour / seven_day and
prompt_cache. Context turns yellow at 50 % (quality starts to slip on very long conversations; finish the feature, then a
fresh one pays off) and red at 80 %. A limit turns yellow at 70 % and red at 90 %, with its reset time. A cold cache means
the whole context is paid in full on the next message: it is the cost of a long conversation after a pause.
"""
import json, sys, time

try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
# Keeps the last payload so the fields Claude Code sends can be inspected.
try:
    with open(__file__.replace("statusline.py", "statusline-last.json"), "w") as dump:
        json.dump(data, dump, indent=1)
except Exception:
    pass

GREEN, YELLOW, RED, DIM, RESET = "\033[32m", "\033[33m", "\033[31m", "\033[90m", "\033[0m"


def color(value, warn, stop):
    return GREEN if value < warn else YELLOW if value < stop else RED


parts = []
model = (data.get("model") or {}).get("display_name", "")
if model:
    parts.append(model)

window = data.get("context_window") or {}
usage = window.get("current_usage") or {}
tokens = sum(usage.get(k, 0) or 0 for k in ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"))
percent = window.get("used_percentage")
if tokens and percent is not None:
    hint = " · finir puis relancer" if percent >= 80 else " · bientôt relancer" if percent >= 50 else ""
    parts.append(f"{color(percent, 50, 80)}{tokens // 1000}k tokens ({percent:.0f} %){hint}{RESET}")

limits = data.get("rate_limits") or {}
for key, label in (("five_hour", "session"), ("seven_day", "semaine")):
    limit = limits.get(key) or {}
    used = limit.get("used_percentage")
    if used is None:
        continue
    text = f"{label} {used:.0f} %"
    if used >= 70 and limit.get("resets_at"):
        text += " (reset " + time.strftime("%H:%M", time.localtime(limit["resets_at"])) + ")"
    parts.append(f"{color(used, 70, 90)}{text}{RESET}")

cache = data.get("prompt_cache") or {}
if cache.get("caching_observed") and cache.get("warm") is False:
    parts.append(f"{YELLOW}cache froid{RESET}")

print(f"{DIM} · {RESET}".join(parts) or "Hexis")
