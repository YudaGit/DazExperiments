# Quick Start Guide - Testing the Current Experiment

## ✅ Setup Status: VERIFIED

All components are properly configured and the server is running!

## Current Status

- ✅ All Python dependencies installed
- ✅ Configuration files correct
- ✅ Static files present
- ✅ Templates exist
- ✅ Server is running on port 5000

## How to Test

### 1. Access the Experiment

Open your web browser and go to:
```
http://localhost:5000/unique-expt
```

### 2. What You Should See

1. **Preload screen** - Loading images
2. **Fullscreen prompt** - Browser will ask for fullscreen
3. **Instructions** - With comprehension checks
4. **Consent form** - Must check box to continue
5. **Demographics** - Colorblind, age, gender questions
6. **Practice trials** - Color patch recall practice
7. **Main experiment** - Color patch recall trials
8. **Debrief** - Completion message

### 3. Testing Checklist

#### Backend (Check Flask Terminal)
- [ ] No Python errors when accessing URL
- [ ] `get_data()` function executes
- [ ] Participant record created (or debug message)

#### Frontend (Check Browser)
- [ ] Page loads without blank screen
- [ ] No JavaScript errors in console (F12)
- [ ] Instructions display correctly
- [ ] Can interact with consent form
- [ ] Can complete practice trials
- [ ] Can complete main experiment
- [ ] Data saves at end

### 4. Browser Console Check

Press **F12** to open developer tools, then:
- Check **Console** tab for errors (red text)
- Check **Network** tab for failed file loads
- Check **Elements** tab to see if content is rendering

### 5. Common Issues & Solutions

#### Issue: Blank page
**Solution:** Check browser console (F12) for JavaScript errors

#### Issue: "Static folder not found"
**Solution:** Verify `static_06d9bffc703f14305bb7357074cf1eb6` folder exists

#### Issue: "get_data() error"
**Solution:** Check `expt_config.py` - make sure `get_data()` returns a dictionary

#### Issue: JavaScript errors
**Solution:** 
- Check that all jsPsych plugins are loaded
- Verify custom functions exist in `colorpatches.js`
- Check that image files exist in `static_*/images/stim/`

#### Issue: Server won't start
**Solution:**
- Check if port 5000 is in use: `netstat -ano | findstr :5000`
- Kill process if needed, or change port in `experiment.py`

## Expected Behavior

### Normal Flow:
1. Server creates participant record (or uses debug mode)
2. Calls `get_data()` to prepare stimuli
3. Renders `exp.html` with data
4. JavaScript loads and runs jsPsych timeline
5. Participant completes experiment
6. Data is sent to `/record-task` endpoint
7. Data is saved (to S3 in production, or local in debug)
8. Debrief page shown

### Debug Mode Behavior:
- AWS errors are caught and logged (not fatal)
- Database errors are caught (participant ID may be '99999999')
- Data still saves locally if S3 fails

## Files to Check if Issues Occur

1. **Browser Console (F12)** - JavaScript errors
2. **Flask Terminal** - Python errors
3. **`expt_config.py`** - Check `get_data()` function
4. **`templates/exp.html`** - Check JavaScript code
5. **`static_*/` folder** - Check files exist

## Next Steps After Testing

Once you've verified the current experiment works:

1. ✅ Understand the structure (you've done this!)
2. ✅ Verify setup works (we're doing this now!)
3. ⏭️ Start converting your Matlab experiment
   - Modify `expt_config.py` for your stimuli
   - Modify `templates/exp.html` for your trial structure
   - Test incrementally

## Server Commands

### Start Server:
```bash
python experiment.py
```

### Stop Server:
Press `Ctrl+C` in the terminal where server is running

### Check if Running:
```bash
netstat -ano | findstr :5000
```

## Need Help?

If you encounter issues:
1. Check browser console (F12)
2. Check Flask server terminal output
3. Review error messages carefully
4. Verify file paths and names match exactly

---

**Ready to test!** Open `http://localhost:5000/unique-expt` in your browser.

