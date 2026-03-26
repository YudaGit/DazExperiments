const rewardConfig = {
  letter: { enabled: true, points: 1 },
  word: { enabled: true, points: 3 },
  task: { enabled: true, points: 5 },
};

const EXPERIMENT_CONFIG = {
  practiceTrials: 1,
  mainTrials: 10,
  taskLengthMode: 'uniform', //'random' = use taskLength category
  uniformTaskLength: 4, // used when taskLengthMode is 'uniform'.
};

const DEADLINE_OPTIONS = [12, 15, 18, 21];

const WORD_LENGTH_RANGES = {
  SS: [2, 4],
  MS: [4, 6],
  ML: [5, 8],
  LL: [7, 10],
};

const TASK_LENGTH_RANGES = {
  sS: [1, 3],
  mS: [2, 5],
  mL: [4, 7],
  lL: [6, 10],
};

const WORD_LENGTH_KEYS = Object.keys(WORD_LENGTH_RANGES);
const TASK_LENGTH_KEYS = Object.keys(TASK_LENGTH_RANGES);

const taskTemplates = [
  { id: 'task-1', label: 'Task 1', color: '#0c6ce1' },
  { id: 'task-2', label: 'Task 2', color: '#0a9adf' },
  { id: 'task-3', label: 'Task 3', color: '#0a98e0' },
  { id: 'task-4', label: 'Task 4', color: '#078ce3' },
];

const state = {
  stage: 'menu',
  participant: {
    name: '_',
    id: '—',
    age: '',
    gender: '',
  },
  score: 0,
  trialMode: null,
  tasks: [],
  engagedTaskId: null,
  taskOrder: [],
  taskCompletionOrder: [],
  dataLog: [],
  currentTrial: null,
  trialMatrix: [],
  taskSwitchLog: [],
  responseLog: [],
  trialStartTime: null,
  trialStartTimestamp: null,
  trialRawInputs: [],
  trialRawRts: [],
  engagementRecords: [],
  currentEngagementRecordIndex: null,
  currentTrialNumber: null,
  autoDownloadTriggered: false,
};

const trialQueues = { practice: [], main: [] };
const mainTrialDataset = [];
const CSV_COLUMNS = [
  'name',
  'age',
  'gender',
  'word_bank',
  'trial_num',
  't1deadline',
  't1tasklength',
  't1words',
  't2deadline',
  't2tasklength',
  't2words',
  't3deadline',
  't3tasklength',
  't3words',
  't4deadline',
  't4tasklength',
  't4words',
  'input_raw',
  'rt_raw',
  'engagement_order',
  'completion_status',
  'switch_flags',
  'trial_result',
  'trial_start',
];
const trialCounters = { practice: 0, main: 0 };
const COMMON_WORD_BANK_PATH = 'word_bank.json';
const UNCOMMON_WORD_BANK_PATH = 'uncommon_word_bank.json';

let wordBankWords = null;
let uncommonWordList = [];
let uncommonWordCursor = 0;
let useUncommonWordBank = false;
let trialsReady = false;

const playerNameEl = document.getElementById('player-name');
const playerScoreEl = document.getElementById('player-score');
const rewardLetterEl = document.getElementById('reward-letter');
const rewardWordEl = document.getElementById('reward-word');
const rewardTaskEl = document.getElementById('reward-task');
const orderListEl = document.getElementById('order-list');
const finalSummaryEl = document.getElementById('final-summary');
const rewardSignalEl = document.getElementById('reward-signal');
const wordListToggleEl = document.getElementById('word-list-toggle');
const wordListDescriptionEl = document.getElementById('word-list-description');
const stagePanelEl = document.getElementById('stage-panel');
const stageScreens = stagePanelEl ? stagePanelEl.querySelectorAll('.stage-screen') : [];
const menuNextButton = document.getElementById('menu-next');
const instructionsBackButton = document.getElementById('instructions-back');
const instructionsNextButton = document.getElementById('instructions-next');
const practiceSkipButton = document.getElementById('practice-skip');
const mainBackButton = document.getElementById('main-back');
const completionHomeButton = document.getElementById('completion-home');
const trialActionButton = document.getElementById('trial-action');
const downloadDataButton = document.getElementById('download-data');
const participantForm = document.getElementById('participant-form');

if (wordListToggleEl) {
  wordListToggleEl.disabled = true;
  wordListToggleEl.checked = false;
}
participantForm?.addEventListener('submit', (event) => {
  event.preventDefault();
});

let rewardTimeout = null;
let lastAnimationFrame = null;

function showStage(stage) {
  state.stage = stage;
  stageScreens.forEach((screen) => {
    screen.classList.toggle('active', screen.dataset.stage === stage);
  });
  if (stage === 'completion') {
    updateFinalSummary();
    if (!state.autoDownloadTriggered && mainTrialDataset.length) {
      downloadMainTrialCSV();
      state.autoDownloadTriggered = true;
    }
  }
  if (stage === 'menu') {
    state.autoDownloadTriggered = false;
  }
  updateTrialActionButton();
}

function updateParticipantDisplay() {
  playerNameEl.textContent = state.participant.name || 'Player';
}

function updateScoreDisplay() {
  playerScoreEl.textContent = state.score;
}

function updateRewardLabels() {
  rewardLetterEl.textContent = rewardConfig.letter.enabled ? `Y (${rewardConfig.letter.points} pts)` : 'N';
  rewardWordEl.textContent = rewardConfig.word.enabled ? `Y (${rewardConfig.word.points} pts)` : 'N';
  rewardTaskEl.textContent = rewardConfig.task.enabled ? `Y (${rewardConfig.task.points} pts)` : 'N';
}

function updateOrderList() {
  if (!state.taskOrder.length) {
    orderListEl.innerHTML = '<li>—</li>';
    return;
  }
  orderListEl.innerHTML = state.taskOrder
    .map((name, index) => `<li>${index + 1}. ${name}</li>`)
    .join('');
}

function shuffle(array) {
  const copy = [...array];
  for (let i = copy.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

async function loadCommonWordBank() {
  const response = await fetch(COMMON_WORD_BANK_PATH);
  if (!response.ok) {
    throw new Error('Unable to load word bank');
  }
  const payload = await response.json();
  return payload.words_by_length || {};
}

async function loadUncommonWordBank() {
  const response = await fetch(UNCOMMON_WORD_BANK_PATH);
  if (!response.ok) {
    throw new Error('Unable to load uncommon word bank');
  }
  const payload = await response.json();
  return payload;
}

async function loadWordBanks() {
  const commonLoader = loadCommonWordBank()
    .then((bank) => {
      wordBankWords = bank;
    })
    .catch(() => {
      wordBankWords = null;
    });
  const uncommonLoader = loadUncommonWordBank()
    .then((payload) => {
      const list = (payload && payload.words) || [];
      uncommonWordList = list.length ? shuffle(list) : [];
    })
    .catch(() => {
      uncommonWordList = [];
    });
  await Promise.all([commonLoader, uncommonLoader]);
  const hasCommonBank = wordBankWords && Object.keys(wordBankWords).length;
  const hasUncommonBank = uncommonWordList.length;
  if (wordListToggleEl) {
    wordListToggleEl.disabled = !hasUncommonBank;
  }
  if (!hasCommonBank && !hasUncommonBank) {
    throw new Error('Unable to load any word bank');
  }
}

function getRandomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function getTaskLengthFromCategory(category) {
  const range = TASK_LENGTH_RANGES[category] || TASK_LENGTH_RANGES.sS;
  return getRandomInt(range[0], range[1]);
}

function recordTrialKeystroke(value) {
  if (state.trialStartTime === null) {
    return;
  }
  const elapsed = Math.round(performance.now() - state.trialStartTime);
  state.trialRawInputs.push(value);
  state.trialRawRts.push(elapsed);
}

function pushEngagementRecord(order) {
  const record = { taskOrder: order, completed: 0, switched: 0 };
  state.engagementRecords.push(record);
  state.currentEngagementRecordIndex = state.engagementRecords.length - 1;
}

function markCurrentEngagementCompleted() {
  if (state.currentEngagementRecordIndex === null) {
    return;
  }
  const entry = state.engagementRecords[state.currentEngagementRecordIndex];
  if (entry) {
    entry.completed = 1;
  }
}

function sampleWordsForRange(range, count, options = {}) {
  if (!wordBankWords || count <= 0 || !range) {
    return Array(Math.max(count, 0)).fill('word');
  }
  const { enforceFirstLetter = false, forbiddenInitials } = options;
  const pool = [];
  for (let length = range[0]; length <= range[1]; length += 1) {
    const bucket = wordBankWords[length] || [];
    pool.push(...bucket);
  }
  if (!pool.length) {
    return Array(count).fill('word');
  }
  const picks = shuffle(pool);
  const selected = [];
  if (enforceFirstLetter && forbiddenInitials instanceof Set) {
    let firstIndex = -1;
    for (let i = 0; i < picks.length; i += 1) {
      const letter = (picks[i][0] || '').toLowerCase();
      if (letter && !forbiddenInitials.has(letter)) {
        firstIndex = i;
        forbiddenInitials.add(letter);
        break;
      }
    }
    if (firstIndex === -1) {
      firstIndex = 0;
      const letter = (picks[0][0] || '').toLowerCase();
      if (letter) {
        forbiddenInitials.add(letter);
      }
    }
    selected.push(picks[firstIndex]);
  } else {
    selected.push(picks[0]);
  }
  for (let i = selected.length; i < count; i += 1) {
    selected.push(picks[i % picks.length]);
  }
  return selected;
}
function sampleUncommonWords(count, options = {}) {
  if (!uncommonWordList.length || count <= 0) {
    return Array(Math.max(count, 0)).fill('word');
  }
  const { enforceFirstLetter = false, forbiddenInitials } = options;
  const selected = [];
  const length = uncommonWordList.length;
  let cursor = uncommonWordCursor;
  if (enforceFirstLetter && forbiddenInitials instanceof Set) {
    let attempts = 0;
    let foundIndex = -1;
    while (attempts < length) {
      const candidateIndex = (cursor + attempts) % length;
      const candidate = uncommonWordList[candidateIndex];
      const initial = (candidate[0] || '').toLowerCase();
      if (initial && !forbiddenInitials.has(initial)) {
        foundIndex = candidateIndex;
        forbiddenInitials.add(initial);
        break;
      }
      attempts += 1;
    }
    if (foundIndex === -1) {
      foundIndex = cursor;
      const initial = (uncommonWordList[foundIndex][0] || '').toLowerCase();
      if (initial) {
        forbiddenInitials.add(initial);
      }
    }
    selected.push(uncommonWordList[foundIndex]);
    cursor = (foundIndex + 1) % length;
  }
  while (selected.length < count) {
    selected.push(uncommonWordList[cursor]);
    cursor = (cursor + 1) % length;
  }
  uncommonWordCursor = cursor;
  return selected;
}
function getOtherTaskInitials(excludeTaskId) {
  const initials = new Set();
  state.tasks.forEach((task) => {
    if (!task || task.id === excludeTaskId || task.completed) {
      return;
    }
    const word = task.words[task.currentIndex] || '';
    const letter = (word[0] || '').toLowerCase();
    if (letter) {
      initials.add(letter);
    }
  });
  return initials;
}

function pickReplacementWordForTask(task, forbiddenInitials) {
  if (!task) {
    return null;
  }
  const options = { enforceFirstLetter: true, forbiddenInitials };
  if (task.wordListType === 'uncommon') {
    const [word] = sampleUncommonWords(1, options);
    return word;
  }
  const range = task.wordRange || WORD_LENGTH_RANGES[task.wordLengthCategory] || WORD_LENGTH_RANGES[WORD_LENGTH_KEYS[0]];
  const [word] = sampleWordsForRange(range, 1, options);
  return word;
}

function replacePartialWord(task) {
  if (!task || task.completed) {
    return;
  }
  const forbiddenInitials = getOtherTaskInitials(task.id);
  const replacement = pickReplacementWordForTask(task, forbiddenInitials);
  if (!replacement) {
    return;
  }
  task.words[task.currentIndex] = replacement;
  task.typedCount = 0;
  updateWordDisplay(task);
}

function buildTrialEntry(mode, index) {
  const deadlines = shuffle(DEADLINE_OPTIONS);
  const wordKeys = useUncommonWordBank ? ['uncommon'] : shuffle([...WORD_LENGTH_KEYS]);
  const taskLengthKeys = shuffle([...TASK_LENGTH_KEYS]);
  const taskPlan = {};
  const wordListType = useUncommonWordBank ? 'uncommon' : 'length-range';
  const initialLetters = new Set();
  taskTemplates.forEach((template, taskIndex) => {
    const deadline = deadlines[taskIndex % deadlines.length];
    const wordCategory = wordKeys[taskIndex % wordKeys.length];
    const wordRange = useUncommonWordBank ? null : WORD_LENGTH_RANGES[wordCategory];
    const taskLength = EXPERIMENT_CONFIG.taskLengthMode === 'uniform'
      ? EXPERIMENT_CONFIG.uniformTaskLength
      : getTaskLengthFromCategory(taskLengthKeys[taskIndex % taskLengthKeys.length]);
    const wordOptions = { enforceFirstLetter: true, forbiddenInitials: initialLetters };
    const words = useUncommonWordBank
      ? sampleUncommonWords(taskLength, wordOptions)
      : sampleWordsForRange(wordRange, taskLength, wordOptions);
    taskPlan[template.id] = {
      deadline,
      wordCategory,
      wordRange,
      taskLength,
      words,
      wordListType,
    };
  });
  return {
    id: `${mode}-${index + 1}`,
    mode,
    taskPlan,
    wordListType,
  };
}

function generateTrialMatrix() {
  const matrix = [];
  ['practice', 'main'].forEach((mode) => {
    const total = mode === 'practice' ? EXPERIMENT_CONFIG.practiceTrials : EXPERIMENT_CONFIG.mainTrials;
    for (let i = 0; i < total; i += 1) {
      matrix.push(buildTrialEntry(mode, i));
    }
  });
  return matrix;
}

function prepareTrialQueues(matrix) {
  trialQueues.practice = matrix.filter((trial) => trial.mode === 'practice');
  trialQueues.main = matrix.filter((trial) => trial.mode === 'main');
}

function initializeTrials() {
  const hasCommonBank = wordBankWords && Object.keys(wordBankWords).length;
  const hasUncommonBank = uncommonWordList.length;
  if (useUncommonWordBank && !hasUncommonBank) return;
  if (!useUncommonWordBank && !hasCommonBank) return;
  trialsReady = false;
  uncommonWordCursor = 0;
  const matrix = generateTrialMatrix();
  state.trialMatrix = matrix;
  prepareTrialQueues(matrix);
  trialsReady = true;
}

function getNextTrial(mode) {
  const queue = trialQueues[mode] || [];
  const pointer = trialCounters[mode] || 0;
  if (pointer >= queue.length) {
    return null;
  }
  return queue[pointer];
}

function updateTrialActionButton() {
  if (!trialActionButton) {
    return;
  }
  if (!['practice', 'main'].includes(state.stage) || state.trialMode) {
    trialActionButton.classList.add('hidden');
    return;
  }
  const nextTrial = getNextTrial(state.stage);
  if (!nextTrial) {
    trialActionButton.classList.add('hidden');
    return;
  }
  const modeDisplay = state.stage === 'practice' ? 'practice' : 'main';
  const count = trialCounters[state.stage] + 1;
  const total = state.stage === 'practice' ? EXPERIMENT_CONFIG.practiceTrials : EXPERIMENT_CONFIG.mainTrials;
  trialActionButton.textContent = `Begin ${modeDisplay} trial ${count}/${total}`;
  trialActionButton.classList.remove('hidden');
}

function maybeCompleteTrial() {
  if (!state.trialMode) {
    return;
  }
  const hasActive = state.tasks.some((task) => !task.completed && !task.deadlineReached);
  if (hasActive) {
    return;
  }
  const completedMode = state.trialMode;
  stopTrial();
  if (completedMode === 'practice') {
    showStage('practice');
    return;
  }
  if (completedMode === 'main') {
    updateFinalSummary();
    if (trialCounters.main >= EXPERIMENT_CONFIG.mainTrials) {
      showStage('completion');
    } else {
      showStage('main');
    }
  }
}

function logTaskSwitch(from, to) {
  state.taskSwitchLog.push({
    from,
    to,
    timestamp: performance.now(),
  });
}

function logResponse(taskId, letter) {
  state.responseLog.push({
    taskId,
    letter,
    timestamp: performance.now(),
  });
}

function createTasksForTrial(trial) {
  if (!trial || !trial.taskPlan) {
    return [];
  }
  return taskTemplates.map((template, index) => {
    const plan = trial.taskPlan[template.id] || {};
    const deadline = plan.deadline || DEADLINE_OPTIONS[0];
    const words = plan.words || [];
    const speed = deadline ? 1 / deadline : 0;
    return {
      ...template,
      words,
      color: template.color,
      deadline,
      wordLengthCategory: plan.wordCategory || WORD_LENGTH_KEYS[0],
      wordRange: plan.wordRange,
      wordListType: plan.wordListType || (useUncommonWordBank ? 'uncommon' : 'length-range'),
      taskLength: plan.taskLength || EXPERIMENT_CONFIG.uniformTaskLength,
      progress: 0,
      speed,
      currentIndex: 0,
      typedCount: 0,
      completed: false,
      deadlineReached: false,
      element: null,
      wordElement: null,
      windowElement: null,
      statusElement: null,
      order: index + 1,
    };
  });
}

function renderTasks() {
  const container = document.getElementById('task-list');
  container.innerHTML = '';
  state.tasks.forEach((task) => {
    const row = document.createElement('div');
    row.className = 'task-row';
    row.dataset.taskId = task.id;

    const label = document.createElement('div');
    label.className = 'task-label';
    label.textContent = task.label;
    row.appendChild(label);

    const track = document.createElement('div');
    track.className = 'task-track';

    const windowEl = document.createElement('div');
    windowEl.className = 'task-window';
    windowEl.style.setProperty('--progress', task.progress);
    windowEl.style.setProperty('--task-color', task.color);

    const wordEl = document.createElement('p');
    wordEl.className = 'task-word';
    windowEl.appendChild(wordEl);

    const statusEl = document.createElement('div');
    statusEl.className = 'status-check';
    statusEl.textContent = '✔';
    statusEl.style.opacity = '0';
    windowEl.appendChild(statusEl);

    track.appendChild(windowEl);
    row.appendChild(track);
    container.appendChild(row);

    task.element = row;
    task.wordElement = wordEl;
    task.windowElement = windowEl;
    task.statusElement = statusEl;

    updateWordDisplay(task);
  });
}

function logTrialData(mode) {
  const trial = state.currentTrial;
  if (!mode || !trial) return;
  const deadlineAssignments = Object.entries(trial.taskPlan).map(([taskId, plan]) => ({
    taskId,
    duration: plan.deadline,
  }));
  const wordAssignments = Object.entries(trial.taskPlan).map(([taskId, plan]) => ({
    taskId,
    wordCategory: plan.wordCategory,
    wordRange: plan.wordRange,
  }));
  const taskLengthAssignments = Object.entries(trial.taskPlan).map(([taskId, plan]) => ({
    taskId,
    length: plan.taskLength,
  }));
  state.dataLog.push({
    trialId: trial.id,
    mode,
    timestamp: new Date().toISOString(),
    score: state.score,
    completionOrder: state.taskCompletionOrder.slice(),
    deadlineAssignments,
    wordAssignments,
    taskLengthAssignments,
    responses: state.responseLog.slice(),
    taskSwitches: state.taskSwitchLog.slice(),
    wordListType: trial.wordListType || (useUncommonWordBank ? 'uncommon' : 'length-range'),
  });
}

function buildMainTrialRow() {
  const trial = state.currentTrial;
  if (!trial) {
    return null;
  }
  const row = {
    name: state.participant.name || 'Player',
    age: state.participant.age || '',
    gender: state.participant.gender || '',
    word_bank: trial.wordListType === 'uncommon' ? 'uncommon' : 'common_length',
    trial_num: state.currentTrialNumber || '',
  };
  taskTemplates.forEach((template, index) => {
    const plan = trial.taskPlan[template.id] || {};
    const prefix = `t${index + 1}`;
    row[`${prefix}deadline`] = plan.deadline || '';
    row[`${prefix}tasklength`] = plan.taskLength || '';
    row[`${prefix}words`] = JSON.stringify(plan.words || []);
  });
  row.input_raw = JSON.stringify(state.trialRawInputs);
  row.rt_raw = JSON.stringify(state.trialRawRts);
  row.engagement_order = JSON.stringify(state.engagementRecords.map((entry) => entry.taskOrder));
  row.completion_status = JSON.stringify(state.engagementRecords.map((entry) => entry.completed));
  row.switch_flags = JSON.stringify(state.engagementRecords.map((entry) => entry.switched));
  const allCompleted = state.tasks.every((task) => task.completed);
  row.trial_result = allCompleted ? 'completed' : 'deadline';
  row.trial_start = state.trialStartTimestamp || '';
  return row;
}

function recordMainTrialRow(mode) {
  if (mode !== 'main') {
    return;
  }
  const row = buildMainTrialRow();
  if (!row) {
    return;
  }
  mainTrialDataset.push(row);
}

function escapeCsvValue(value) {
  if (value === null || value === undefined) {
    return '';
  }
  const str = String(value);
  if (/[",\n]/.test(str)) {
    return `"${str.replace(/"/g, '""')}"`;
  }
  return str;
}

function downloadMainTrialCSV() {
  if (!mainTrialDataset.length) {
    showRewardSignal('No main trial data has been collected yet.', true);
    return;
  }
  const lines = [CSV_COLUMNS.join(',')];
  mainTrialDataset.forEach((row) => {
    const line = CSV_COLUMNS.map((column) => escapeCsvValue(row[column])).join(',');
    lines.push(line);
  });
  const blob = new Blob([lines.join('\n')], { type: 'text/csv' });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url;
  const stamp = new Date().toISOString().slice(0, 19).replace(/:/g, '-');
  anchor.download = `deadline_trials_${stamp}.csv`;
  document.body.appendChild(anchor);
  anchor.click();
  document.body.removeChild(anchor);
  URL.revokeObjectURL(url);
}

function shouldHighlight(task) {
  if (task.completed || task.deadlineReached) {
    return false;
  }
  if (!state.engagedTaskId) {
    return true;
  }
  return state.engagedTaskId === task.id;
}

function updateWordDisplay(task) {
  if (!task.wordElement) return;
  const word = task.words[task.currentIndex] || '';
  if (!word) {
    task.wordElement.innerHTML = '<span class="first-letter">—</span>';
    return;
  }
  const remaining = word.slice(task.typedCount);
  const first = remaining.charAt(0) || '';
  const rest = remaining.slice(1);
  const highlightClass = shouldHighlight(task) ? 'first-letter highlight' : 'first-letter';
  task.wordElement.innerHTML = `<span class="${highlightClass}">${first}</span><span class="rest-word">${rest}</span>`;
}

function updateTaskClasses() {
  state.tasks.forEach((task) => {
    if (!task.element) return;
    const row = task.element;
    row.classList.toggle('engaged', state.engagedTaskId === task.id && !task.completed);
    row.classList.toggle('dimmed', Boolean(state.engagedTaskId && state.engagedTaskId !== task.id && !task.completed));
  });
}

function releaseEngagement(reason = 'auto') {
  const task = state.tasks.find((t) => t.id === state.engagedTaskId);
  if (task && task.typedCount > 0 && task.currentIndex < task.words.length) {
    replacePartialWord(task);
  }
  if (state.engagedTaskId) {
    logTaskSwitch(state.engagedTaskId, null);
  }
  state.engagedTaskId = null;
  if (state.currentEngagementRecordIndex !== null) {
    if (reason === 'switch') {
      const entry = state.engagementRecords[state.currentEngagementRecordIndex];
      if (entry) {
        entry.switched = 1;
      }
    }
    state.currentEngagementRecordIndex = null;
  }
  updateTaskClasses();
  state.tasks.forEach(updateWordDisplay);
}
function engageTask(task) {
  if (task.completed || task.deadlineReached) return;
  if (state.engagedTaskId !== task.id) {
    logTaskSwitch(state.engagedTaskId, task.id);
  }
  state.engagedTaskId = task.id;
  pushEngagementRecord(task.order);
  if (!state.taskOrder.includes(task.label)) {
    state.taskOrder.push(task.label);
    updateOrderList();
  }
  updateTaskClasses();
  updateWordDisplay(task);
}

function findActivatableTask(letter) {
  const unused = state.tasks
    .filter((task) => !task.completed && !task.deadlineReached && task.words[task.currentIndex])
    .sort((a, b) => b.progress - a.progress);
  return unused.find((task) => (task.words[task.currentIndex][0] || '').toLowerCase() === letter);
}

function handleCorrectLetter(task, letter = '') {
  const word = task.words[task.currentIndex] || '';
  if (!word) return;
  logResponse(task.id, letter);
  task.typedCount += 1;
  if (rewardConfig.letter.enabled && rewardConfig.letter.points) {
    awardPoints('letter', rewardConfig.letter.points);
  }
  if (task.typedCount >= word.length) {
    completeWord(task);
  } else {
    updateWordDisplay(task);
  }
}

function completeWord(task) {
  const word = task.words[task.currentIndex] || '';
  if (rewardConfig.word.enabled && rewardConfig.word.points) {
    awardPoints('word', rewardConfig.word.points);
  }
  task.currentIndex += 1;
  task.typedCount = 0;
  if (task.currentIndex >= task.words.length) {
    finishTask(task);
  } else {
    updateWordDisplay(task);
  }
}

function finishTask(task) {
  markCurrentEngagementCompleted();
  task.completed = true;
  task.progress = 1;
  task.windowElement?.style.setProperty('--progress', 1);
  task.element?.classList?.add('completed');
  task.statusElement?.style.setProperty('opacity', '1');
  if (rewardConfig.task.enabled && rewardConfig.task.points) {
    awardPoints('task', rewardConfig.task.points);
  }
  state.taskCompletionOrder.push(task.label);
  if (state.engagedTaskId === task.id) {
    releaseEngagement('auto');
  }
  maybeCompleteTrial();
}

function showTypingError(task) {
  if (!task.wordElement) return;
  task.wordElement.classList.add('error');
  setTimeout(() => task.wordElement.classList.remove('error'), 300);
  showRewardSignal('Oops, wrong letter', true);
}

function awardPoints(type, points) {
  if (!points) return;
  state.score += points;
  updateScoreDisplay();
  const typeLabel = type === 'letter' ? 'Letter' : type === 'word' ? 'Word' : 'Task';
  showRewardSignal(`+${points} ${typeLabel}`);
}

function showRewardSignal(message, isError = false) {
  rewardSignalEl.textContent = message;
  rewardSignalEl.style.background = isError ? '#ff4d4f' : 'rgba(12, 108, 225, 0.92)';
  rewardSignalEl.classList.add('pop');
  if (rewardTimeout) {
    clearTimeout(rewardTimeout);
  }
  rewardTimeout = setTimeout(() => {
    rewardSignalEl.classList.remove('pop');
  }, 1100);
}

function animateTracks(timestamp) {
  if (!lastAnimationFrame) {
    lastAnimationFrame = timestamp;
  }
  const delta = (timestamp - lastAnimationFrame) / 1000;
  lastAnimationFrame = timestamp;
  if (state.trialMode) {
    state.tasks.forEach((task) => {
      if (task.completed || task.deadlineReached) {
        return;
      }
      task.progress = Math.min(1, task.progress + task.speed * delta);
      task.windowElement?.style?.setProperty('--progress', task.progress);
      if (task.progress >= 1) {
        task.deadlineReached = true;
        task.element?.classList?.add('deadline');
        if (state.engagedTaskId === task.id) {
          releaseEngagement();
        }
      }
    });
  }
  maybeCompleteTrial();
  requestAnimationFrame(animateTracks);
}

function startTrial(mode) {
  if (!trialsReady) {
    showRewardSignal('Trial matrix still loading. Please wait.', true);
    return;
  }
  const trial = getNextTrial(mode);
  if (!trial) {
    showRewardSignal(`No more ${mode} trials are available.`, true);
    return;
  }
  state.currentTrial = trial;
  state.trialMode = mode;
  state.engagedTaskId = null;
  state.taskOrder = [];
  state.taskCompletionOrder = [];
  state.score = 0;
  state.responseLog = [];
  state.taskSwitchLog = [];
  state.tasks = createTasksForTrial(trial);
  state.trialRawInputs = [];
  state.trialRawRts = [];
  state.engagementRecords = [];
  state.currentEngagementRecordIndex = null;
  trialCounters[mode] += 1;
  state.currentTrialNumber = trialCounters[mode];
  state.trialStartTime = performance.now();
  state.trialStartTimestamp = new Date().toISOString();
  renderTasks();
  updateScoreDisplay();
  updateOrderList();
  updateTrialActionButton();
}

function stopTrial() {
  const previous = state.trialMode;
  logTrialData(previous);
  recordMainTrialRow(previous);
  state.trialMode = null;
  releaseEngagement();
  state.trialStartTime = null;
  state.trialStartTimestamp = null;
  state.trialRawInputs = [];
  state.trialRawRts = [];
  state.engagementRecords = [];
  state.currentEngagementRecordIndex = null;
  state.currentTrialNumber = null;
  updateTrialActionButton();
}

function updateFinalSummary() {
  const completed = state.taskCompletionOrder.length;
  if (finalSummaryEl) {
    finalSummaryEl.textContent = `Final score: ${state.score} pts · Tasks completed: ${completed} / ${taskTemplates.length}`;
  }
}

window.addEventListener('keydown', (event) => {
  if (!state.trialMode) {
    return;
  }
  if (event.key === 'Escape') {
    recordTrialKeystroke('ESC');
    releaseEngagement('switch');
    return;
  }
  if (event.key.length !== 1) return;
  const letter = event.key.toLowerCase();
  if (!/[a-z]/.test(letter)) return;
  if (!state.engagedTaskId) {
    const candidate = findActivatableTask(letter);
    if (candidate) {
      recordTrialKeystroke(letter);
      engageTask(candidate);
      handleCorrectLetter(candidate, letter);
    }
    else {
      recordTrialKeystroke('xx');
    }
    return;
  }
  const task = state.tasks.find((t) => t.id === state.engagedTaskId);
  if (!task) return;
  if (task.completed || task.deadlineReached) {
    releaseEngagement();
    return;
  }
  const currentWord = task.words[task.currentIndex] || '';
  const expected = (currentWord[task.typedCount] || '').toLowerCase();
  if (letter === expected) {
    recordTrialKeystroke(letter);
    handleCorrectLetter(task, letter);
  } else {
    recordTrialKeystroke('xx');
    showTypingError(task);
  }
});

if (wordListToggleEl) {
  wordListToggleEl.addEventListener('change', () => {
    useUncommonWordBank = wordListToggleEl.checked;
    updateWordListDescription();
    stopTrial();
    trialsReady = false;
    initializeTrials();
  });
}

menuNextButton?.addEventListener('click', () => {
  const nameInput = document.getElementById('participant-name')?.value.trim() || '';
  const ageInput = document.getElementById('participant-age')?.value.trim() || '';
  const genderInput = document.getElementById('participant-gender')?.value || '';
  state.participant.name = nameInput || 'Player';
  state.participant.age = ageInput || '';
  state.participant.gender = genderInput || '';
  updateParticipantDisplay();
  showStage('instructions');
});

instructionsBackButton?.addEventListener('click', () => {
  showStage('menu');
});

instructionsNextButton?.addEventListener('click', () => {
  showStage('practice');
});

practiceSkipButton?.addEventListener('click', () => {
  showStage('main');
});

mainBackButton?.addEventListener('click', () => {
  showStage('practice');
});

completionHomeButton?.addEventListener('click', () => {
  showStage('menu');
});

trialActionButton?.addEventListener('click', () => {
  const mode = state.stage === 'practice' ? 'practice' : state.stage === 'main' ? 'main' : null;
  if (!mode) {
    return;
  }
  startTrial(mode);
});

downloadDataButton?.addEventListener('click', downloadMainTrialCSV);

updateParticipantDisplay();
updateRewardLabels();
updateScoreDisplay();
updateOrderList();
showStage('menu');
loadWordBanks()
  .then(() => {
    updateWordListDescription();
    initializeTrials();
  })
  .catch(() => {
    showRewardSignal('Unable to load word banks. Trial presets are unavailable.', true);
  });
requestAnimationFrame(animateTracks);

function updateWordListDescription() {
  if (!wordListDescriptionEl) return;
  if (wordListToggleEl && wordListToggleEl.disabled) {
    wordListDescriptionEl.textContent = 'Uncommon word bank is unavailable; length ranges remain active.';
    return;
  }
  wordListDescriptionEl.textContent = useUncommonWordBank
    ? 'Using the uncommon word list; length ranges are skipped.'
    : 'Using the length-range word bank (word_bank.json).';
}
















