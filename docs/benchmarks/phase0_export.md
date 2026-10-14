# Phase 0 — Export Throughput Benchmarks (Windows)

Measured via `[Benchmark]` debug log lines emitted during manual testing.

## How to collect

1. Run the app on Windows in debug mode (`flutter run -d windows`).
2. Trigger an **Export folder to ZIP** operation.
3. In the debug console, look for:
   - `[Benchmark] Export: <N>ms, <N> MB/s`
4. Record the values in the table below.

## Results

| Device | ZIP size (MB) | Export ms | MB/s | Notes |
|--------|--------------|-----------|------|-------|
|        |              |           |      |       |
