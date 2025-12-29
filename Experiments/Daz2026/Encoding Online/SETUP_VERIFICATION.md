# Setup Verification Report

## Test Results

All basic setup tests **PASSED** ✓

### ✅ Verified Components:

1. **Python Dependencies**
   - Flask ✓
   - config ✓
   - expt_config ✓
   - MallExperiment ✓
   - SimpleDB ✓
   - user_utils ✓

2. **Configuration**
   - EXPT_UID: `06d9bffc703f14305bb7357074cf1eb6` ✓
   - DEBUG: `True` ✓
   - RESULTS_DIR: `2023/FougnieTask2023_2/results` ✓

3. **Experiment Configuration**
   - `get_data()` function exists ✓
   - Returns correct data structure ✓
   - Keys: `['study_list', 'test_list', 'study_document_order']` ✓

4. **Static Files**
   - Static folder exists: `static_06d9bffc703f14305bb7357074cf1eb6` ✓
   - Required templates exist ✓
   - Stimulus file exists: `word-list.json.gz` ✓

5. **JavaScript Dependencies**
   - Custom functions defined in `colorpatches.js` ✓
   - Functions referenced in `exp.html`:
     - `shuffleRedundancy()` ✓
     - `selectRedundantColorPatches()` ✓
     - `getRandomIntegers()` ✓
     - `highRGBs` variable ✓

## Next Steps to Test

### 1. Start the Server

```bash
python experiment.py
```

Or:

```bash
flask run
```

### 2. Access the Experiment

Open your browser and visit:
```
http://localhost:5000/unique-expt
```

### 3. What to Check

#### Backend (Python)
- [ ] Server starts without errors
- [ ] No import errors in console
- [ ] `get_data()` is called successfully
- [ ] Data is passed to template correctly

#### Frontend (JavaScript)
- [ ] Page loads without errors
- [ ] Check browser console (F12) for JavaScript errors
- [ ] jsPsych loads correctly
- [ ] Custom plugins load correctly
- [ ] Experiment timeline starts
- [ ] Instructions display correctly
- [ ] Trials execute properly
- [ ] Responses are collected
- [ ] Data is saved at the end

### 4. Common Issues to Watch For

#### If server doesn't start:
- Check if port 5000 is already in use
- Verify virtual environment is activated
- Check for missing dependencies

#### If page doesn't load:
- Check browser console (F12) for errors
- Verify static files are accessible
- Check network tab for failed requests

#### If experiment doesn't run:
- Check browser console for JavaScript errors
- Verify jsPsych plugins are loaded
- Check that custom functions are defined
- Verify data structure matches what JavaScript expects

## Testing Checklist

- [ ] Server starts successfully
- [ ] Can access `/unique-expt` route
- [ ] Page loads without errors
- [ ] No JavaScript console errors
- [ ] Instructions display correctly
- [ ] Consent form works
- [ ] Practice trials run
- [ ] Main experiment trials run
- [ ] Responses are collected
- [ ] Data saves successfully
- [ ] Debrief page displays

## Known Potential Issues

### 1. AWS Credentials (if not in DEBUG mode)
- In DEBUG mode, AWS operations may fail gracefully
- For production, AWS credentials need to be configured
- This is expected and won't prevent local testing

### 2. Database Operations (SimpleDB)
- In DEBUG mode, database errors are caught and handled
- May see debug messages about AWS keys - this is normal for local development

### 3. Static File Loading
- Make sure static folder name matches `static_{EXPT_UID}`
- Currently: `static_06d9bffc703f14305bb7357074cf1eb6` ✓

## Files Status

| File | Status | Notes |
|------|--------|-------|
| `experiment.py` | ✓ | Generic framework - no changes needed |
| `config.py` | ✓ | Configured correctly |
| `expt_config.py` | ✓ | `get_data()` function works |
| `templates/exp.html` | ✓ | Template exists and loads dependencies |
| `static_*/` folder | ✓ | Contains all required files |
| `word-list.json.gz` | ✓ | Stimulus file exists |

## Summary

The project setup appears to be **correct and ready to run**. All dependencies are installed, configuration is correct, and required files are present.

**To proceed:**
1. Start the server: `python experiment.py`
2. Open browser: `http://localhost:5000/unique-expt`
3. Test the experiment flow
4. Check browser console for any runtime errors

If you encounter any issues during runtime testing, check:
- Browser console (F12) for JavaScript errors
- Flask server terminal for Python errors
- Network tab for failed file loads

