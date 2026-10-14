# Phase 0 — Import Throughput Benchmarks

Measured via `[Benchmark]` debug log lines emitted during manual testing.

## How to collect

1. Run the app in debug mode (`flutter run`).
2. Trigger a bulk folder import or a ZIP import.
3. In the debug console, look for:
   - `[Benchmark] Import: <N> files/s, <N> MB/s` — aggregate throughput after the full batch.
   - `[Benchmark] Import: file <bytes> bytes in <N>ms (<N> MB/s)` — per-file timing.
   - `[Benchmark] ZIP import: <N>ms, <N> MB/s` — ZIP import path timing.
4. Record the values in the table below.

## Results

| Device | File count | Total size (MB) | files/s | MB/s | Notes |
|--------|-----------|-----------------|---------|------|-------|
|        |           |                 |         |      |       |
