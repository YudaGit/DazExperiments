# Typing Deadline Scheduling Experiment

## Project Description
- A browser-based typing experiment that visualizes per-task deadlines via animated windows racing toward a finish line.
- Record trial metadata (deadline, word-length, task-length assignments) plus keystroke/task-switch logs so downstream analyses can reconstruct each session.
- Keep the UI responsive, legible, and easy to operate (highlighted first letters, ESC to release, visual reward cues).

## Layout & UX
- Experiment now opens to a Main Menu page where participants enter their info and choose toggles. The staged flow progresses through Instruction, Practice (with optional repeat/skip), and Main Block screens so each view can take full browser width before revealing the next screen.
- A single experiment panel below the viewport now hosts the task windows; it displays participant name, score, reward cues, task ordering info, and (between trials only) a `Begin Next Trial` button so users cannot terminate a running trial.
- Task windows continue to move from the right to the left finish line, use high-contrast colors per task, show highlighted upcoming words, and carry deadline badges ([styles.css](styles.css)).
    - Pressing space/enter no longer hijacks the trial-start flow because each stage is fully modal and practice/main buttons are disabled until their prerequisites complete.

## Experiment parameters & trial generation
- Configuration via `EXPERIMENT_CONFIG`, `DEADLINE_OPTIONS`, `WORD_LENGTH_RANGES`, and `TASK_LENGTH_RANGES` in `app.js`. These constants controls:
 - Total N of practice and main trials 
 - Deadline durations(4 lvs) 
 - Word length categories (SS to LL)
 - Task length categories (sS to lL)
 - Task lengths toggle between uniform or random.
 
 - The word bank is loaded from `word_bank.json` (with an optional toggle to switch to an `uncommon_word_bank.json` file) to generate a full `trialMatrix`, containing practice/main queues, and mark `trialsReady` so the practice/main buttons only run once presets exist.
    - Older `word_length_ranges` logic remains available when the toggle is off; the uncommon list ignores length buckets because it relies on uniformly uncommon entries to standardize difficulty.
    - Tasks now enforce unique initial letters across the four windows and immediately discard any partial word (if a participant disengages mid-word) in favor of a fresh word that also respects the unique-initial constraint.

- `buildTrialEntry()` assembles each trial’s per-task plan (deadline, word category/range, task length, sampled words) using a pre-shuffled selection to avoid patterns; Word sampling pulls uniformly from the allowed length buckets, wraps when the pool is smaller than the desired number of words, and uses placeholder strings if the bank is not yet available.
    - Discuss sampling methods

- `startTrial()` pulls the next pre-generated trial, resets engagement/score/logs, and renders tasks with their assigned deadlines so every run follows the predetermined plan.

- toggle between preemptive version and non-premptive version
    - must finish current word, not for now

## Data logging
- Logs stored in `state.dataLog` capture the trial ID, mode, deadlines, word-length categories, task lengths, completion order, keystroke responses (letter + timestamp), and task switches (from → to plus timestamp) every time `stopTrial()` ends a trial.
- A parallel `mainTrialDataset` records one row per main trial (name, age, gender, word_bank, trial_num, each task’s deadline/task length/word list, `input_raw`, `rt_raw`, `engagement_order`, `completion_status`, `switch_flags`, trial_result, and trial_start). The completion screen exposes a “Download CSV” button and auto-downloads when the block finishes so the full dataset can be saved locally.
- Separate `state.responseLog`/`taskSwitchLog` buffers accumulate data during a trial and are flushed into the data log to maintain per-trial granularity.
- Current trial metadata (`state.currentTrial`, `state.trialMatrix`, `trialQueues`, `trialCounters`) stay accessible to export or resume logic later.

## Interaction behaviors
- Typing locks into a task when the first letter is pressed; ESC releases engagement and logs the switch. Correct keystrokes award configurable points for letters, words, and tasks, while errors briefly flash the current word and show an error signal.
- Deadline animation updates `task.progress` toward 1 at speed `1/deadline`, so 10/15/20/25 second deadlines manifest as proportional rates. Tasks freeze with a checkmark once completed and turn red if they hit the deadline.

## Next documentation steps
- Extend `DESIGN.md` with a simple data schema and export plan once storage requirements are finalized.
- Capture the final trial matrix structure and any backend integration details in a future revision when persistence targets (local file, server) are chosen.

To do:
- key block and data saving -- OK
- get Dan's word bank -- OK
- new word if disengage mid word -- OK
- no overlap initial letters -- OK
- Help coding environment -- OK

23/03/2026
- Yunni test and task update
- CHDH server
- REP/Prolific setup
