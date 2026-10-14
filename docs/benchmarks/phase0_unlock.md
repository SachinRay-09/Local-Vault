# Phase 0 — Unlock Timing Benchmarks

Measured via `[Benchmark]` debug log lines emitted during manual testing.

## How to collect

1. Run the app in debug mode (`flutter run`).
2. Open the app, enter your password, and tap **Unlock**.
3. In the debug console, look for:
   - `[Benchmark] KDF duration: <N>ms` — time spent in PBKDF2 key derivation.
   - `[Benchmark] Total unlock: <N>ms` — time from button tap to navigation.
4. Record the values in the table below.

## Results

| Device | KDF ms | Total unlock ms | Notes |
|--------|--------|-----------------|-------|
|        |        |                 |       |
