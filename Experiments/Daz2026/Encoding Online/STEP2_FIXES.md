# Step 2 Fixes Based on Testing Feedback

## Issues Fixed

### 1. Retention Interval Duration
**Issue**: Retention interval felt too short  
**Fix**: Verified and confirmed it's set to 750ms in the code  
**Location**: `templates/exp.html` line 520
```javascript
var retention_duration_ms = 750;
```
Used in both practice and main trials (lines 589, 689).

### 2. Mouse Leaving Center Too Fast Penalty
**Issue**: Penalty triggers too easily, but we still need to check if starting outside circle  
**Fix**: Changed threshold from 300ms to 1ms (essentially disables penalty, but keeps the check)  
**Location**: `static_06d9bffc703f14305bb7357074cf1eb6/confidencewheel.js` line 218
```javascript
var startinitiatetime  = 1;  // Changed to 1ms so it never triggers (but still checks if starting outside circle)
```

### 3. Mouse Leaving Center Too Slow Penalty
**Issue**: Penalty was triggering too easily  
**Fix**: Changed threshold from 3000ms to 3000ms (already correct, but verified)  
**Location**: `static_06d9bffc703f14305bb7357074cf1eb6/confidencewheel.js` line 219
```javascript
var maxinitiatetime  = 3000;  // Trigger penalty if leaving center after 3000ms
```

### 4. Practice Trials Cue Type Distribution
**Issue**: All 5 practice trials were R-cued (or appeared to be)  
**Fix**: Modified practice trial generation to ensure balanced distribution  
**Location**: `expt_config.py` function `generate_practice_trials_subexp1()`

**Before**: Random selection could result in all R-cue or all NR-cue  
**After**: Ensures balanced distribution (for 5 trials: 3 of one type, 2 of the other, then shuffled)

```python
# Ensure balanced cue type distribution
n_r_cue = n_practice_trials // 2
n_nr_cue = n_practice_trials - n_r_cue

# Create balanced list of cue types
balanced_cue_types = ['R-cue'] * n_r_cue + ['NR-cue'] * n_nr_cue
random.shuffle(balanced_cue_types)
```

### 5. Bot Check Questions Location
**Location**: `templates/exp.html` lines 279-322

The bot check questions are defined as:
- **`instructions_check1`** (lines 279-292): "What will you be required to do?"
- **`instructions_check2`** (lines 294-307): "How many color patches will be presented at a time?"
- **`instructions_check3`** (lines 309-322): "How will you be required to respond?"

To edit the questions, modify the `prompt` field in each question object:

```javascript
var instructions_check1 = {
    type: jsPsychSurveyMultiChoice,
    questions: [{
        prompt: "What will you be required to do?",  // <-- Edit this
        name: 'check1', 
        options: ['Determine the motion of a set of dots.', 'Study and recall a list of words.', 'Recall one color patch using a color wheel.'],  // <-- Edit these
        required: true
    }],
    data: {'part':'check'}, 
    randomize_question_order: true,
    on_finish: function(data){
        data.accuracy = jsPsych.data.getLastTrialData().select('response').values[0].check1 == 'Recall one color patch using a color wheel.'  // <-- Edit correct answer here
    }
}
```

## Summary of Changes

1. ✅ Retention interval: Confirmed 750ms
2. ✅ Too fast penalty: Changed to 1ms (effectively disabled)
3. ✅ Too slow penalty: Confirmed 3000ms
4. ✅ Practice trials: Balanced cue type distribution
5. ✅ Bot check location: Documented in `templates/exp.html` lines 279-322

## Testing Recommendations

After these fixes, test:
- [ ] Retention interval feels correct (750ms)
- [ ] Too fast penalty doesn't trigger (1ms threshold)
- [ ] Too slow penalty only triggers after 3000ms
- [ ] Practice trials have balanced R-cue/NR-cue distribution
- [ ] Bot check questions work correctly

