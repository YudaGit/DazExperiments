# Typing Deadline Scheduling Experiment

## Project Description
- A browser-based typing experiment that visualizes per-task deadlines via animated windows racing toward a finish line.
- Record trial metadata (deadline, word-length, task-length assignments) plus keystroke/task-switch logs so downstream analyses can reconstruct each session.
- Keep the UI responsive, legible, and easy to operate (highlighted first letters, ESC to release, visual reward cues).

## Layout & UX
- Two-column layout split between an information panel (name/score, reward flags, trial order, flow screens) and a dynamic `track-viewport` with animated task windows ([index.html](index.html)).
    - Can try staged design, so information/setting panel is its own page.

- Task windows move from the right edge toward the left finish line, have high-contrast colors per task, show the upcoming word with the first letter highlighted, and present a deadline badge ([styles.css](styles.css)).
    - Deadline visually more salient?
    - First letter highlight need to be more salient

- Flow sections (welcome, participant info, instructions, practice/main/completion) are overlaid inside the info panel to match the prescribed experimental stages.
    - Issue: pressing space/enter during a trial seems to trigger the "begin trial" button, which cuts the current trial off and initiates a new one. Need to either block keys or force a trial to finish

## Experiment parameters & trial generation
- Configuration via `EXPERIMENT_CONFIG`, `DEADLINE_OPTIONS`, `WORD_LENGTH_RANGES`, and `TASK_LENGTH_RANGES` in `app.js`. These constants controls:
 - Total N of practice and main trials 
 - Deadline durations(4 lvs) 
 - Word length categories (SS to LL)
 - Task length categories (sS to lL)
 - Task lengths toggle between uniform or random.
 
 - The word bank is loaded from `word_bank.json` on startup to generate a full `trialMatrix`, containing practice/main queues, and mark `trialsReady` so the practice/main buttons only run once presets exist.
    - word bank update to uncommon words

- `buildTrialEntry()` assembles each trial’s per-task plan (deadline, word category/range, task length, sampled words) using a pre-shuffled selection to avoid patterns; Word sampling pulls uniformly from the allowed length buckets, wraps when the pool is smaller than the desired number of words, and uses placeholder strings if the bank is not yet available.
    - Discuss sampling methods

- `startTrial()` pulls the next pre-generated trial, resets engagement/score/logs, and renders tasks with their assigned deadlines so every run follows the predetermined plan.

- toggle between preemptive version and non-premptive version
    - must finish current word, not for now

## Data logging
- Logs stored in `state.dataLog` capture the trial ID, mode, deadlines, word-length categories, task lengths, completion order, keystroke responses (letter + timestamp), and task switches (from → to plus timestamp) every time `stopTrial()` ends a trial.
- Separate `state.responseLog`/`taskSwitchLog` buffers accumulate data during a trial and are flushed into the data log to maintain per-trial granularity.
- Current trial metadata (`state.currentTrial`, `state.trialMatrix`, `trialQueues`, `trialCounters`) stay accessible to export or resume logic later.

## Interaction behaviors
- Typing locks into a task when the first letter is pressed; ESC releases engagement and logs the switch. Correct keystrokes award configurable points for letters, words, and tasks, while errors briefly flash the current word and show an error signal.
- Deadline animation updates `task.progress` toward 1 at speed `1/deadline`, so 10/15/20/25 second deadlines manifest as proportional rates. Tasks freeze with a checkmark once completed and turn red if they hit the deadline.

## Next documentation steps
- Extend `DESIGN.md` with a simple data schema and export plan once storage requirements are finalized.
- Capture the final trial matrix structure and any backend integration details in a future revision when persistence targets (local file, server) are chosen.

To do:
- key block and data saving
- Yunni test and task update
    - get Dan's word bank
    - new word if disengage mid word
    - update color coding
    - no overlap initial letters
- Help coding environment, CHDH server, REP/Prolific setup
