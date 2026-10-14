# Phase 0 — Frame Jank Baseline

No code changes needed. Use Flutter DevTools to measure frame build time and jank count.

## Steps

1. **Start DevTools**
   - Run the app: `flutter run`
   - In the terminal output, find the DevTools URL (e.g. `http://127.0.0.1:9100?uri=...`).
   - Open that URL in a browser.

2. **Enable Performance Overlay** (optional quick view)
   - In DevTools, go to the **Performance** tab.
   - Or in the app itself, enable the performance overlay via Flutter inspector.

3. **Record a baseline**
   - Navigate to the import screen.
   - Start a timeline recording in DevTools (**Performance → Record**).
   - Trigger an import of ~100 files.
   - Stop the recording.

4. **Measure**
   - In the flame chart, note the **max frame build time** (UI thread, in ms).
   - Count frames that exceed 16 ms (60 fps budget) — these are jank frames.
   - The DevTools **Frame chart** shows a red bar for frames over budget.

5. **Record results**

| Device | Max frame build (ms) | Jank frame count | Notes |
|--------|----------------------|-----------------|-------|
|        |                      |                 |       |
