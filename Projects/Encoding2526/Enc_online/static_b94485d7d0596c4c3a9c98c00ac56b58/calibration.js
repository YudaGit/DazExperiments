/* Credit-card calibration helper
   - Shows a small UI to measure pixels per millimeter using a standard credit card width (85.6 mm)
   - Saves value to localStorage as 'pxPerMm' and exposes window.pxPerMm
   - Simple, minimal UI that can be skipped
*/
(function(){
  function setPxPerMm(pxPerMm){
    window.pxPerMm = pxPerMm;
    try{ localStorage.setItem('pxPerMm', String(pxPerMm)); }catch(e){}
    console.log('Calibration: pxPerMm=', pxPerMm);
  }

  function restore(){
    try{
      const v = localStorage.getItem('pxPerMm');
      if (v){ window.pxPerMm = Number(v); }
    }catch(e){}
  }

  function showModal(opts){
    opts = opts || {};
    var force = !!opts.force;
    var onSave = typeof opts.onSave === 'function' ? opts.onSave : null;
    if (window.pxPerMm && !force) return; // already calibrated unless forced

    // Create modal overlay and box
    const overlay = document.createElement('div');
    overlay.id = 'calib-overlay';
    Object.assign(overlay.style, {
      position: 'fixed', left:0, top:0, right:0, bottom:0, background:'rgba(0,0,0,0.75)', zIndex: 99999,
      display:'flex', alignItems:'center', justifyContent:'center'
    });

    const box = document.createElement('div');
    Object.assign(box.style, { background:'#fff', color:'#000', padding:'18px', borderRadius:'8px', width:'640px', maxWidth:'95%'});

    const title = document.createElement('h3'); title.textContent = 'Screen calibration';
    title.style.margin = '0 0 8px 0';
    const p = document.createElement('p');
    p.style.margin = '0 0 12px 0';
    p.textContent = 'Please place a standard credit card sideways (horizontally) on your screen and drag the left/right sliders to match the white line to card edges, and click the SAVE button. This ensures correct stimuli size for your screen. After calibration, please proceed with the experiment with the screen at about arm\'s length (50-70cm) for best results.';
    box.appendChild(title);
    box.appendChild(p);

    const trackWrap = document.createElement('div');
    Object.assign(trackWrap.style, {position:'relative', height:'80px', border:'1px solid #ccc', background:'#f7f7f7', overflow:'hidden'});
    const track = document.createElement('div');
    track.id = 'calib-track';
    Object.assign(track.style, {position:'relative', height:'100%', width:'100%'});
    trackWrap.appendChild(track);
    box.appendChild(trackWrap);

    // handles with center reference lines
    const left = document.createElement('div');
    left.id = 'calib-left';
    Object.assign(left.style, {position:'absolute', top:'18px', left:'10px', width:'12px', height:'44px', background:'#444', cursor:'ew-resize', borderRadius:'3px'});
    // Add center reference line (1px wide, centered in the slider)
    const leftLine = document.createElement('div');
    Object.assign(leftLine.style, {position:'absolute', left:'5.5px', top:'0px', width:'1px', height:'100%', background:'#fff', pointerEvents:'none'});
    left.appendChild(leftLine);
    
    const right = document.createElement('div');
    right.id = 'calib-right';
    Object.assign(right.style, {position:'absolute', top:'18px', right:'10px', width:'12px', height:'44px', background:'#444', cursor:'ew-resize', borderRadius:'3px'});
    // Add center reference line (1px wide, centered in the slider)
    const rightLine = document.createElement('div');
    Object.assign(rightLine.style, {position:'absolute', left:'5.5px', top:'0px', width:'1px', height:'100%', background:'#fff', pointerEvents:'none'});
    right.appendChild(rightLine);
    
    track.appendChild(left);
    track.appendChild(right);

    // measured display and buttons
    const controls = document.createElement('div');
    Object.assign(controls.style, {marginTop:'12px', display:'flex', gap:'8px', alignItems:'center'});
    const saveBtn = document.createElement('button'); saveBtn.id = 'calib-save'; saveBtn.textContent = 'Save';
    controls.appendChild(saveBtn);
    if (!force){ const skipBtn = document.createElement('button'); skipBtn.id = 'calib-skip'; skipBtn.textContent = 'Skip'; controls.appendChild(skipBtn); }
    const measuredWrap = document.createElement('div'); measuredWrap.style.marginLeft = 'auto'; measuredWrap.innerHTML = 'Measured: <span id="calib-measured">0</span> px';
    controls.appendChild(measuredWrap);
    box.appendChild(controls);

    overlay.appendChild(box);
    document.body.appendChild(overlay);

    let dragging = null;

    function updateMeasured(){
      const lrect = left.getBoundingClientRect();
      const rrect = right.getBoundingClientRect();
      // Measure from center of left slider to center of right slider (center line to center line)
      const leftCenter = lrect.left + (lrect.width / 2);
      const rightCenter = rrect.left + (rrect.width / 2);
      const px = Math.max(1, Math.round(rightCenter - leftCenter));
      const measured = box.querySelector('#calib-measured');
      if (measured) measured.textContent = px;
      return px;
    }

    function onMouseDown(e){
      if (e.target === left) dragging = 'left';
      else if (e.target === right) dragging = 'right';
    }
    function onMouseMove(e){
      if (!dragging) return;
      const rect = track.getBoundingClientRect();
      const x = Math.max(2, Math.min(rect.width - 2, e.clientX - rect.left));
      if (dragging === 'left'){
        // Drag left slider: move left slider toward center, right slider away from center (mirror)
        const leftPos = x - (left.offsetWidth/2);
        const rightPos = (rect.width - x - (right.offsetWidth/2));
        left.style.left = leftPos + 'px';
        right.style.left = rightPos + 'px';
      } else {
        // Drag right slider: move right slider toward center, left slider away from center (mirror)
        const rightPos = x - (right.offsetWidth/2);
        const leftPos = (rect.width - x - (left.offsetWidth/2));
        right.style.left = rightPos + 'px';
        left.style.left = leftPos + 'px';
      }
      updateMeasured();
    }
    function onMouseUp(){ dragging = null; }

    left.addEventListener('mousedown', onMouseDown);
    right.addEventListener('mousedown', onMouseDown);
    window.addEventListener('mousemove', onMouseMove);
    window.addEventListener('mouseup', onMouseUp);

    saveBtn.addEventListener('click', function(){
      const px = updateMeasured();
      const pxPerMm = px / 85.6;
      console.log('Calibration: measured px=' + px + ', calculated pxPerMm=' + pxPerMm.toFixed(3) + ' (implies 1mm=' + pxPerMm.toFixed(1) + 'px)');
      console.log('At 5mm stimulus radius: expected pixels=' + (pxPerMm * 5).toFixed(1) + ', diameter=' + (pxPerMm * 10).toFixed(1) + 'px');
      setPxPerMm(pxPerMm);
      cleanup();
      if (onSave) onSave(pxPerMm);
    });
    const skipElement = box.querySelector('#calib-skip');
    if (skipElement){ skipElement.addEventListener('click', cleanup); }

    function cleanup(){
      left.removeEventListener('mousedown', onMouseDown);
      right.removeEventListener('mousedown', onMouseDown);
      window.removeEventListener('mousemove', onMouseMove);
      window.removeEventListener('mouseup', onMouseUp);
      overlay.remove();
    }

    // initialize positions
    setTimeout(()=>{
      const rect = track.getBoundingClientRect();
      left.style.left = '10px';
      right.style.left = (rect.width - 22) + 'px';
      updateMeasured();
    },50);
  }

  // public API
  window.calibration = {
    init: restore,
    showModal: showModal,
    setPxPerMm: setPxPerMm
  };
  // restore on load
  restore();
})();
