#!/usr/bin/env python3
"""Summarize measured CS528-HW8 CSV files (no dependencies)."""
import csv
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent / 'results'
for filename in ('hw8-baseline.csv', 'hw8-failover.csv'):
    rows = list(csv.DictReader((BASE / filename).open(newline='')))
    valid = [r for r in rows if r['status'] == '200' and r['zone'] != 'UNKNOWN']
    errors = [r for r in rows if r not in valid]
    counts = Counter(r['zone'] for r in valid)
    print('\n' + filename)
    print('Requests:', len(rows), 'Successes:', len(valid), 'Errors:', len(errors))
    for zone, count in sorted(counts.items()):
        print(f'  {zone}: {count} ({100 * count / len(valid):.2f}%)')
    if errors:
        first, last = errors[0], errors[-1]
        print('First error:', first['timestamp_utc'])
        print('Last error: ', last['timestamp_utc'])
        print('First success after last error:', next((r['timestamp_utc'] for r in rows if r['status'] == '200' and r['request'].isdigit() and int(r['request']) > int(last['request'])), 'None'))
print('\nRecovery: service start 2026-11-19 23:48:07 UTC; first VM1 client request at 23:48:33 UTC (~26s, 1-second log resolution).')
