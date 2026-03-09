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

const DEADLINE_OPTIONS = [12, 18, 24, 30];

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
  stage: 'welcome',
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
};

const trialQueues = { practice: [], main: [] };
const trialCounters = { practice: 0, main: 0 };
let wordBankWords = null;
let trialsReady = false;

const playerNameEl = document.getElementById('player-name');
const playerScoreEl = document.getElementById('player-score');
const playerIdEl = document.getElementById('player-id');
const playerDemoEl = document.getElementById('player-demographics');
const rewardLetterEl = document.getElementById('reward-letter');
const rewardWordEl = document.getElementById('reward-word');
const rewardTaskEl = document.getElementById('reward-task');
const orderListEl = document.getElementById('order-list');
const practiceStatusEl = document.getElementById('practice-status');
const mainStatusEl = document.getElementById('main-status');
const feedbackQuoteEl = document.getElementById('feedback-quote');
const finalSummaryEl = document.getElementById('final-summary');
const rewardSignalEl = document.getElementById('reward-signal');

let rewardTimeout = null;
let lastAnimationFrame = null;

function showStage(stage) {
  state.stage = stage;
  document.querySelectorAll('.stage-screen').forEach((screen) => {
    screen.classList.toggle('active', screen.dataset.stage === stage);
  });
}

function updateParticipantDisplay() {
  playerNameEl.textContent = state.participant.name || 'Player';
  playerIdEl.textContent = state.participant.id ? `ID: ${state.participant.id}` : 'ID: —';
  const age = state.participant.age ? `Age ${state.participant.age}` : '';
  const gender = state.participant.gender ? state.participant.gender : '';
  playerDemoEl.textContent = [age, gender].filter(Boolean).join(' / ') || '—';
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

async function loadWordBank() {
  const response = await fetch('word_bank.json');
  if (!response.ok) {
    throw new Error('Unable to load word bank');
  }
  const payload = await response.json();
  return payload.words_by_length || {};
}

function getRandomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function getTaskLengthFromCategory(category) {
  const range = TASK_LENGTH_RANGES[category] || TASK_LENGTH_RANGES.sS;
  return getRandomInt(range[0], range[1]);
}

function sampleWordsForRange(range, count) {
  if (!wordBankWords) {
    return Array(count).fill('word');
  }
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
  for (let i = 0; i < count; i += 1) {
    selected.push(picks[i % picks.length]);
  }
  return selected;
}

function buildTrialEntry(mode, index) {
  const deadlines = shuffle(DEADLINE_OPTIONS);
  const wordKeys = shuffle([...WORD_LENGTH_KEYS]);
  const taskLengthKeys = shuffle([...TASK_LENGTH_KEYS]);
  const taskPlan = {};
  taskTemplates.forEach((template, taskIndex) => {
    const deadline = deadlines[taskIndex % deadlines.length];
    const wordCategory = wordKeys[taskIndex % wordKeys.length];
    const wordRange = WORD_LENGTH_RANGES[wordCategory];
    const taskLength = EXPERIMENT_CONFIG.taskLengthMode === 'uniform'
      ? EXPERIMENT_CONFIG.uniformTaskLength
      : getTaskLengthFromCategory(taskLengthKeys[taskIndex % taskLengthKeys.length]);
    const words = sampleWordsForRange(wordRange, taskLength);
    taskPlan[template.id] = {
      deadline,
      wordCategory,
      wordRange,
      taskLength,
      words,
    };
  });
  return {
    id: `${mode}-${index + 1}`,
    mode,
    taskPlan,
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
  if (!wordBankWords) return;
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
    label.innerHTML = `
      <span>${task.label}</span>
      <span class="deadline-value">${task.deadline}s</span>
    `;
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
  });
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

function releaseEngagement() {
  if (state.engagedTaskId) {
    logTaskSwitch(state.engagedTaskId, null);
  }
  state.engagedTaskId = null;
  updateTaskClasses();
  state.tasks.forEach(updateWordDisplay);
}

function engageTask(task) {
  if (task.completed || task.deadlineReached) return;
  if (state.engagedTaskId !== task.id) {
    logTaskSwitch(state.engagedTaskId, task.id);
  }
  state.engagedTaskId = task.id;
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
    releaseEngagement();
  }
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
  trialCounters[mode] += 1;
  renderTasks();
  updateScoreDisplay();
  updateOrderList();
  updateStageStatus('practice',
    mode === 'practice'
      ? 'Practice trial is live. Lock into a task to begin typing.'
      : 'Use this stage to get comfortable with the layout, unlocking tasks as each word shows up.');
  updateStageStatus('main',
    mode === 'main'
      ? 'Main trial is live. Focus on accuracy and speed.'
      : 'Type the words for real. Rewards are already logged as you type.');
}

function stopTrial() {
  const previous = state.trialMode;
  logTrialData(previous);
  state.trialMode = null;
  releaseEngagement();
  if (previous === 'practice') {
    updateStageStatus('practice', 'Practice paused. Use Begin practice to restart.');
  }
  if (previous === 'main') {
    updateStageStatus('main', 'Main trials paused. Begin when you are ready.');
  }
}

function updateStageStatus(stageKey, text) {
  if (stageKey === 'practice' && practiceStatusEl) {
    practiceStatusEl.textContent = text;
  }
  if (stageKey === 'main' && mainStatusEl) {
    mainStatusEl.textContent = text;
  }
}

function updateFeedbackQuote() {
  const path = state.taskOrder.length ? state.taskOrder.join(' → ') : 'none yet';
  if (feedbackQuoteEl) {
    feedbackQuoteEl.textContent = `You navigated tasks in this order: ${path}. Ready for the main trials?`;
  }
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
    releaseEngagement();
    return;
  }
  if (event.key.length !== 1) return;
  const letter = event.key.toLowerCase();
  if (!/[a-z]/.test(letter)) return;
  if (!state.engagedTaskId) {
    const candidate = findActivatableTask(letter);
    if (candidate) {
      engageTask(candidate);
      handleCorrectLetter(candidate, letter);
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
    handleCorrectLetter(task, letter);
  } else {
    showTypingError(task);
  }
});

document.querySelectorAll('[data-next-stage]').forEach((button) => {
  button.addEventListener('click', () => {
    showStage(button.dataset.nextStage);
  });
});

document.getElementById('participant-next').addEventListener('click', () => {
  const nameInput = document.getElementById('participant-name').value.trim();
  const idInput = document.getElementById('participant-id').value.trim();
  const ageInput = document.getElementById('participant-age').value.trim();
  const genderInput = document.getElementById('participant-gender').value;
  state.participant.name = nameInput || 'Player';
  state.participant.id = idInput || '—';
  state.participant.age = ageInput || '';
  state.participant.gender = genderInput || '';
  updateParticipantDisplay();
  showStage('instructions');
});

document.getElementById('begin-practice').addEventListener('click', () => {
  startTrial('practice');
  showStage('practice');
});

document.getElementById('finish-practice').addEventListener('click', () => {
  stopTrial();
  updateFeedbackQuote();
  showStage('feedback');
});

document.getElementById('start-main').addEventListener('click', () => {
  showStage('main');
});

document.getElementById('begin-main').addEventListener('click', () => {
  startTrial('main');
});

document.getElementById('finish-main').addEventListener('click', () => {
  stopTrial();
  updateFinalSummary();
  showStage('completion');
});

updateParticipantDisplay();
updateRewardLabels();
updateScoreDisplay();
updateOrderList();
showStage('welcome');
loadWordBank()
  .then((bank) => {
    wordBankWords = bank;
    initializeTrials();
  })
  .catch(() => {
    showRewardSignal('Unable to load word bank. Trial presets are unavailable.', true);
  });
requestAnimationFrame(animateTracks);
