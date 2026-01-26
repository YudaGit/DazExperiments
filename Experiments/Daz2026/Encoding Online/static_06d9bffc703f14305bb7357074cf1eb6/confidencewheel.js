var jsConfidenceWheel = (function (jspsych) {
    'use strict';
    const info = {
        name: "confidence-wheel",
        parameters: {
            wheel_rotation: {
                type: jspsych.ParameterType.INT,
                pretty_name: "Stimulus Rotation",
                default: 0,
            },
            /** Array containing the color(s) of the button(s). */
            choice_colors: {
                type: jspsych.ParameterType.array,
                pretty_name: "Button Colors",
                default: [],
                array: true,
            },
            /** Array containing the position(s) of the button(s). */
            patch_positionalangle: {
                type: jspsych.ParameterType.array,
                pretty_name: "Button Position Angles",
                default: [],
                array: true,
            },
            /** Array containing the color angle(s) of the button(s). */
            choice_colorangles: {
                type: jspsych.ParameterType.array,
                pretty_name: "Button Color Angles",
                default: [],
                array: true,
            },
            /** How long to show the trial. */
            trial_duration: {
                type: jspsych.ParameterType.INT,
                pretty_name: "Trial duration",
                default: null,
            }, 
            redundancy:{
                type: jspsych.ParameterType.INT,
                pretty_name: "Redundancy",
                default: null,
            },
            target_index:{
                type: jspsych.ParameterType.INT,
                pretty_name: "Target Index",
                default: null,
            },
            orientations:{
                type: jspsych.ParameterType.array,
                pretty_name: "Orientations",
                default: null,
                array: true,
            },
            stimulus_type:{
                type: jspsych.ParameterType.STRING,
                pretty_name: "Stimulus Type",
                default: 'color_patches',  // 'color_patches' or 'orientation_bars'
            },
            response_type:{
                type: jspsych.ParameterType.STRING,
                pretty_name: "Response Type",
                default: 'color_wheel',  // 'color_wheel' or 'orientation_bar'
            },
            show_mask:{
                type: jspsych.ParameterType.BOOL,
                pretty_name: "Show Visual Mask",
                default: false,  // Show visual mask (for Sub-Experiment 3 retention interval)
            },
            mask_data:{
                type: jspsych.ParameterType.OBJECT,
                pretty_name: "Mask Data",
                default: null,  // Pre-generated mask data (colors, orientations, positions)
            },
            mask_scale: {
                type: jspsych.ParameterType.FLOAT,
                pretty_name: "Mask Bar Scale",
                default: 0.8,  // Mask bar size relative to stimulus bars
            },
            pause_each_stage: {
                type: jspsych.ParameterType.BOOL,
                pretty_name: "Pause Each Stage",
                default: false
            }
        }   
    }

    class ConfidenceWheelPlugin {
        constructor(jsPsych) {
            this.jsPsych = jsPsych;
            this._maskCache = null;
        }

        findTargetIndex(colorAngles, isRedundant) {
            let frequencyMap = {};
            let targetN = undefined;
    
            // Build frequency map
            colorAngles.forEach(angle => {
                frequencyMap[angle] = (frequencyMap[angle] || 0) + 1;
            });
    
            if (isRedundant) {
                // Find the first repeating angle's index
                for (let angle of colorAngles) {
                    if (frequencyMap[angle] > 1) {
                        targetN = colorAngles.indexOf(angle);
                        break;
                    }
                }
            } else {
                // Find the first non-repeating angle's index, or select random if no redundant angle
                let nonRepeatingFound = false;
                for (let angle of colorAngles) {
                    if (frequencyMap[angle] === 1) {
                        targetN = colorAngles.indexOf(angle);
                        nonRepeatingFound = true;
                        break;
                    }
                }
    
                // If no non-repeating angle is found (i.e., all angles are unique), select random
                if (!nonRepeatingFound) {
                    targetN = Math.floor(Math.random() * colorAngles.length);
                }
            }
    
            return targetN;
        }

        generateDefaultPositions(count) {
            if (!count || count <= 0) {
                return [];
            }
            const spacing = 360 / count;
            const positions = [];
            for (let i = 0; i < count; i++) {
                positions.push((i * spacing) % 360);
            }
            return positions;
        }

        drawOrientationBars(ctx, trial, centerX, centerY, patchradius, patchRadius) {
            /**
             * Draw colored orientation bars for Sub-Experiment 3
             * 
             * Bar dimensions:
             * - Length: approximately equal to color patch diameter (2 * patchRadius)
             * - Width:Length ratio = 1:7
             * - Each bar has a color and orientation (0-180°)
             */
            
            // Bar length = diameter of color patch
            var barLength = 2 * patchRadius;
            // Bar width = length / 7 (1:7 ratio)
            var barWidth = barLength / 7;
            
            // Draw each bar
            for (var ii = 0; ii < trial.patch_positionalangle.length; ii++) {
                // Calculate bar center position (same as patch position)
                var posAngle = trial.patch_positionalangle[ii] * Math.PI / 180;
                var barCenterX = centerX + patchradius * Math.cos(posAngle);
                var barCenterY = centerY + patchradius * Math.sin(posAngle);
                
                // Get bar color
                var rgbstr = 'rgb(' + trial.choice_colors[ii][0] + ',' + 
                                      trial.choice_colors[ii][1] + ',' + 
                                      trial.choice_colors[ii][2] + ')';
                
                // Get bar orientation (convert to radians, 0-180° -> 0-π)
                var orientationRad = trial.orientations[ii] * Math.PI / 180;
                
                // Save context state
                ctx.save();
                
                // Translate to bar center
                ctx.translate(barCenterX, barCenterY);
                
                // Rotate to bar orientation
                ctx.rotate(orientationRad);
                
                // Draw bar (centered at origin after translation/rotation)
                ctx.fillStyle = rgbstr;
                ctx.strokeStyle = rgbstr;
                ctx.fillRect(-barLength/2, -barWidth/2, barLength, barWidth);
                ctx.strokeRect(-barLength/2, -barWidth/2, barLength, barWidth);
                
                // Restore context state
                ctx.restore();
            }
        }

        drawOrientationBarResponse(ctx, trial, centerX, centerY, targetN, patchRadius) {
            /**
             * Draw orientation bar response interface for Sub-Experiment 3
             * 
             * Draws a single orientation bar at center (colored like target)
             * This bar serves as both cue and response interface
             * Mouse up/down rotates the bar, click confirms response
             */
            
            // Bar length = diameter of color patch
            var barLength = 2 * patchRadius;
            // Bar width = length / 7 (1:7 ratio)
            var barWidth = barLength / 7;
            
            // Get target color (bar color matches target item)
            var targetColor = trial.choice_colors[targetN];
            var rgbstr = 'rgb(' + targetColor[0] + ',' + targetColor[1] + ',' + targetColor[2] + ')';
            
            // Initial orientation (will be updated by mouse movement)
            // Store in trial object so it persists across redraws
            if (trial.current_orientation === undefined) {
                trial.current_orientation = 0; // Start at 0°
            }
            
            // Draw the orientation bar at center
            ctx.save();
            ctx.translate(centerX, centerY);
            ctx.rotate(trial.current_orientation * Math.PI / 180); // Rotate to current orientation
            
            ctx.fillStyle = rgbstr;
            ctx.strokeStyle = rgbstr;
            ctx.lineWidth = 2;
            ctx.fillRect(-barLength/2, -barWidth/2, barLength, barWidth);
            ctx.strokeRect(-barLength/2, -barWidth/2, barLength, barWidth);
            
            ctx.restore();
            
            // drawVisualMask only paints on the provided ctx/canvas
        }

        drawOrientationBarFeedback(ctx, trial, centerX, centerY, targetN, patchRadius, responseOrientation, targetOrientation) {
            /**
             * Draw feedback for orientation bar response
             * Shows response orientation (white bar) and correct orientation (green bar)
             */
            
            var barLength = 2 * patchRadius;
            var barWidth = barLength / 7;
            var targetColor = trial.choice_colors[targetN];
            
            // Draw response orientation (white bar)
            ctx.save();
            ctx.translate(centerX, centerY);
            ctx.rotate(responseOrientation * Math.PI / 180);
            ctx.fillStyle = 'white';
            ctx.strokeStyle = 'white';
            ctx.lineWidth = 2;
            ctx.fillRect(-barLength/2, -barWidth/2, barLength, barWidth);
            ctx.strokeRect(-barLength/2, -barWidth/2, barLength, barWidth);
            ctx.restore();
            
            // Draw correct orientation (green outline, centered)
            ctx.save();
            ctx.translate(centerX, centerY);
            ctx.rotate(targetOrientation * Math.PI / 180);
            ctx.strokeStyle = 'lime';
            ctx.lineWidth = 2;
            var outlineScale = 1.10; // 10% larger than stimulus bar
            var outlineLength = barLength * outlineScale;
            var outlineWidth = barWidth * outlineScale;
            ctx.strokeRect(-outlineLength/2, -outlineWidth/2, outlineLength, outlineWidth);
            ctx.restore();
            
            // drawVisualMask only paints on the provided ctx/canvas
        }

        generateVisualMask(centerX, centerY, maskRadius, barRadius, numBars) {
            /**
             * Generate visual mask data for Sub-Experiment 3 retention interval
             * 
             * Creates random colored orientation bars covering the entire mask area
             * Mask is a circle that fully covers the stimulus display area
             * 
             * @param {number} centerX - X coordinate of mask center
             * @param {number} centerY - Y coordinate of mask center
             * @param {number} maskRadius - Radius of mask circle (larger than stimulus area)
             * @param {number} barRadius - Radius of individual bars (same as stimulus bars)
             * @param {number} numBars - Number of bars to generate (dense coverage)
             * @returns {Object} Mask data with colors, orientations, and positions
             */
            
            var maskData = {
                colors: [],
                orientations: [],
                positions: []
            };
            
            // Bar dimensions (same as stimulus bars)
            var barLength = 2 * barRadius;
            var barWidth = barLength / 7;
            
            // Generate random bars covering the mask area
            // Use a grid-based approach with some randomness for dense coverage
            var gridSize = Math.ceil(Math.sqrt(numBars));
            var cellSize = (maskRadius * 2) / gridSize;
            
            for (var i = 0; i < numBars; i++) {
                // Random position within mask circle
                var angle = Math.random() * 2 * Math.PI;
                var distance = Math.random() * maskRadius;
                var x = centerX + distance * Math.cos(angle);
                var y = centerY + distance * Math.sin(angle);
                
                // Ensure bar is within mask circle (accounting for bar length)
                var distFromCenter = Math.sqrt((x - centerX) ** 2 + (y - centerY) ** 2);
                if (distFromCenter + barLength/2 > maskRadius) {
                    // Adjust position to keep bar within circle
                    var adjustFactor = (maskRadius - barLength/2) / distFromCenter;
                    x = centerX + (x - centerX) * adjustFactor;
                    y = centerY + (y - centerY) * adjustFactor;
                }
                
                // Random color (0-360°)
                var colorAngle = Math.floor(Math.random() * 360);
                var colorRGB = this.colorAngleToRGB(colorAngle);
                
                // Random orientation (0-180°)
                var orientation = Math.random() * 180;
                
                maskData.colors.push(colorRGB);
                maskData.orientations.push(orientation);
                maskData.positions.push({x: x, y: y});
            }
            
            return maskData;
        }

        colorAngleToRGB(angle) {
            /**
             * Convert color angle (0-360°) to RGB
             * Uses the same color space as the color wheel
             */
            // Use the highRGBs array if available (from color wheel)
            if (typeof highRGBs !== 'undefined' && highRGBs.length > 0) {
                var index = Math.round(angle) % 360;
                return highRGBs[index];
            }
            
            // Fallback: simple HSV to RGB conversion
            var h = angle / 360;
            var s = 1.0;
            var v = 0.8;
            
            var c = v * s;
            var x = c * (1 - Math.abs((h * 6) % 2 - 1));
            var m = v - c;
            
            var r, g, b;
            if (h < 1/6) { r = c; g = x; b = 0; }
            else if (h < 2/6) { r = x; g = c; b = 0; }
            else if (h < 3/6) { r = 0; g = c; b = x; }
            else if (h < 4/6) { r = 0; g = x; b = c; }
            else if (h < 5/6) { r = x; g = 0; b = c; }
            else { r = c; g = 0; b = x; }
            
            return [
                Math.round((r + m) * 255),
                Math.round((g + m) * 255),
                Math.round((b + m) * 255)
            ];
        }

        drawVisualMask(ctx, trial, centerX, centerY, maskRadius, barRadius) {
            /**
             * Draw visual mask for Sub-Experiment 3 retention interval
             * 
             * Draws a dense array of random colored orientation bars
             * covering the entire mask area (circle)
             */
            
            var maskData = this._maskCache;
            const scale = (typeof trial.mask_scale === 'number' && !isNaN(trial.mask_scale))
                ? trial.mask_scale
                : 0.8;
            const scaledBarRadius = barRadius * scale;
            
            // Use pre-generated mask data if available, otherwise generate once per session
            if (!maskData || !maskData.colors || maskData.colors.length === 0) {
                // Generate mask data (dense coverage: ~1500 bars for full coverage)
                var numBars = 1500;
                maskData = this.generateVisualMask(centerX, centerY, maskRadius, scaledBarRadius, numBars);
                this._maskCache = maskData;
            }
            
            // Bar dimensions (same as stimulus bars)
            var barLength = 2 * scaledBarRadius;
            var barWidth = barLength / 7;
            
            // Draw all bars
            for (var i = 0; i < maskData.colors.length; i++) {
                var color = maskData.colors[i];
                var orientation = maskData.orientations[i];
                var pos = maskData.positions[i];
                
                var rgbstr = 'rgb(' + color[0] + ',' + color[1] + ',' + color[2] + ')';
                var orientationRad = orientation * Math.PI / 180;
                
                // Draw bar
                ctx.save();
                ctx.translate(pos.x, pos.y);
                ctx.rotate(orientationRad);
                
                ctx.fillStyle = rgbstr;
                ctx.strokeStyle = rgbstr;
                ctx.lineWidth = 1;
                ctx.fillRect(-barLength/2, -barWidth/2, barLength, barWidth);
                ctx.strokeRect(-barLength/2, -barWidth/2, barLength, barWidth);
                
                ctx.restore();
            }
            
            // drawVisualMask only paints on the provided ctx/canvas
        }

        trial(display_element, trial) {
            // Set Base Variables
            var self = this;
            var maxtime = 10000
            var startingradius = Math.round(window.outerHeight * 0.035);
            var windowHeight = (typeof browser_window_height === 'number' && !isNaN(browser_window_height))
                ? browser_window_height
                : window.outerHeight;
            var patchradius    = windowHeight * .1;
            var targetN;

            // Ensure patch positions exist for drawing orientation bars
            if (!Array.isArray(trial.patch_positionalangle) || trial.patch_positionalangle.length === 0) {
                const fallbackCount = Array.isArray(trial.choice_colors) && trial.choice_colors.length
                    ? trial.choice_colors.length
                    : (Array.isArray(trial.orientations) ? trial.orientations.length : 0);
                trial.patch_positionalangle = this.generateDefaultPositions(fallbackCount);
            }
            if (trial.draw_wheel == true){
                // If target_index is explicitly provided, use it
                if (trial.target_index !== null && trial.target_index !== undefined) {
                    targetN = trial.target_index;
                } else if (trial.redundancy == 1) {
                    targetN = this.findTargetIndex(trial.choice_colorangles, true);
                } else {
                    targetN = this.findTargetIndex(trial.choice_colorangles, false);
                }
            }

            // Create canvas 95% of screen w/h for drawing (avoids scroll trigger)
            var canvas = document.createElement("canvas");
            canvas.style.margin = "0";
            canvas.style.padding = "0";
            var ctx = canvas.getContext("2d");
            ctx.canvas.width  = window.outerWidth * 0.95;
            ctx.canvas.height = window.outerHeight * 0.95;
            
            //  Add central white circle for mouse centering (skip for orientation-bar response)
            var midx = ctx.canvas.width/2
            var midy = ctx.canvas.height/2
            if (!(trial.draw_wheel === true && trial.response_type === 'orientation_bar')) {
                const circle = new Path2D();
                circle.arc(midx, midy, startingradius, 0, 2 * Math.PI);
                ctx.strokeStyle = 'white';
                ctx.border = 'thick';
                ctx.stroke(circle);
            }
            // Always attach canvas; response type decides what is drawn on it
            display_element.insertBefore(canvas, null);
            
            var indiv_patch_radius = Math.round(window.outerHeight * 0.024)
            //console.log('p', indiv_patch_radius)
            
            if (trial.draw_wheel == false){
                const displayDuration = (typeof trial.trial_duration === 'number' && !isNaN(trial.trial_duration))
                    ? trial.trial_duration
                    : 0;
                if (trial.pause_each_stage) {
                    setupPauseKey();
                } else {
                    // Set timeout when showing stimuli
                    this.jsPsych.pluginAPI.setTimeout(() => {
                        end_trial();
                    }, displayDuration);
                    // Secondary native timeout as a failsafe
                    setTimeout(() => {
                        end_trial();
                    }, displayDuration + 10);
                }
                
                // Check if showing visual mask (for Sub-Experiment 3 retention interval)
                if (trial.show_mask == true) {
                    // Calculate mask radius (larger than stimulus area to fully cover it)
                    // Stimulus centers are on a circle, so bars extend outside that circle
                    // Mask radius = patch radius + bar length (to fully cover)
                    var barLength = 2 * indiv_patch_radius;
                    var maskRadius = patchradius + barLength;
                    
                    // Draw visual mask
                    this.drawVisualMask(ctx, trial, midx, midy, maskRadius, indiv_patch_radius);
                    display_element.insertBefore(canvas, null);
                }
                // Check stimulus type
                else if (trial.stimulus_type === 'orientation_bars' && trial.orientations) {
                    // Draw Colored Orientation Bars
                    this.drawOrientationBars(ctx, trial, midx, midy, patchradius, indiv_patch_radius);
                    display_element.insertBefore(canvas, null);
                } else {
                    // Draw Colored Patches (default)
                    for (var ii = 0; ii < trial.patch_positionalangle.length; ii++){
                        var patches = new Path2D();
                        patches.arc(midx + patchradius * Math.cos( trial.patch_positionalangle[ii] * Math.PI/180 ), 
                                    midy + patchradius * Math.sin( trial.patch_positionalangle[ii] * Math.PI/180 ), 
                                    indiv_patch_radius, 0, 2 * Math.PI);
                        var rgbstr = 'rgb(' + trial.choice_colors[ii][0] + ',' + 
                                              trial.choice_colors[ii][1] + ',' + 
                                              trial.choice_colors[ii][2] + ')'
                        ctx.strokeStyle = rgbstr
                        ctx.fillStyle   = rgbstr
                        ctx.fill(patches);
                        ctx.stroke(patches);
                        display_element.insertBefore(canvas, null); 
                    }
                }
            }
            
            if (trial.draw_wheel == true){
                
                // Check response type
                if (trial.response_type === 'orientation_bar') {
                    // ============================================================
                    // ORIENTATION BAR RESPONSE (Sub-Experiment 3)
                    // ============================================================
                    // Draw orientation bar at center (serves as cue and response interface)
                    // Bar color matches target item color
                    // Mouse up/down rotates bar, click confirms
                    
                    this.drawOrientationBarResponse(ctx, trial, midx, midy, targetN, indiv_patch_radius);
                    
                } else {
                    // ============================================================
                    // COLOR WHEEL RESPONSE (Sub-Experiments 1 & 2)
                    // ============================================================
                    
                    // Calculate Wheel Colors + Rotation
                    const vector = [...Array(360).keys()];
                    // console.log(vector)
                    const vectorPlus = vector.map((element) => element - Number(trial.wheel_rotation));
                    const wrappedVector = vectorPlus.map((element) => {
                        if (element >= 359) {return element - 359 }
                        else if (element < 0) { return element + 359 } 
                        else { return element }
                    });      
                    
                    var rgbs = wrappedVector.map((index) => highRGBs[index]);
                    
                    
                
                    // Draw Color Wheel                
                    var outer_radius = Math.round( window.outerHeight * 0.230 )
                    var inner_radius = Math.round(outer_radius - window.outerHeight * 0.026)

                    
                    var graphics = canvas.getContext("2d");
                    // console.log(Number(trial.wheel_rotation))
                    // console.log(rgbs)
                    for (ii = 0; ii < 359.5; ii += 0.01){
                        var rad = ii * (2*Math.PI) / 360;
                        graphics.strokeStyle = "rgb("+ rgbs[Math.round(ii)][0] +"," + rgbs[Math.round(ii)][1] + "," + rgbs[Math.round(ii)][2] + ")"
                        graphics.lineWidth = outer_radius/125
                        graphics.beginPath();
                        graphics.moveTo(midx + outer_radius * Math.cos(rad), midy + outer_radius * Math.sin(rad) )
                        graphics.lineTo(midx + inner_radius * Math.cos(rad), midy + inner_radius * Math.sin(rad) )
                        graphics.stroke();
                    }
                    display_element.insertBefore(canvas, null);
                    ctx.save();

                    for (var ii = 0; ii < trial.patch_positionalangle.length; ii++){
                        var patches = new Path2D();
                        patches.arc(midx + patchradius * Math.cos( trial.patch_positionalangle[ii] * Math.PI/180 ), 
                                    midy + patchradius * Math.sin( trial.patch_positionalangle[ii] * Math.PI/180 ), 
                                    indiv_patch_radius, 0, 2 * Math.PI);
                        if (ii == targetN){
                            ctx.lineWidth = 3
                            ctx.strokeStyle = 'white'
                        } else {
                            ctx.strokeStyle = 'rgb( 128, 128, 128 )'
                        }
                        ctx.fillStyle   = 'rgb( 128, 128, 128 )'
                        ctx.fill(patches);
                        ctx.stroke(patches);
                        display_element.insertBefore(canvas, null); 
                    }
                }

                
            }

            // Add Mouse Tracking Element
            var mouse_coords = [];
            var mouse_coord_rts = [];            
            var leavecenterRT = [];
            var pastXcoords = [];
            var pastYcoords = [];

            var startinitiatetime  = 1;  // Changed to 1ms so it never triggers (but still checks if starting outside circle)
            var maxinitiatetime  = 3000;  // Trigger penalty if leaving center after 3000ms

            var toofast = [false];
            var tooslow = [false];
            var timeout = [false];
            var startoutofCenter = [false]; 

            var leavecenter = false;  
            var responded = false;

            var resp_error = []
            var rt = []
            var degrees = []
            var radians = []
            var derotated_degrees = []
            var finished = false

            var start_time = performance.now();
            var finX = []
            var finY = []

            var x_mouse = 0
            var y_mouse = 0

            var interval = 5;
            var interval_count = 0

            var points = []

            var endtrial = false
            var mousecheckinterval
            var pauseKeyListener = null;
            var feedbackKeyListener = null;

            function setupPauseKey() {
                if (!trial.pause_each_stage) {
                    return;
                }
                if (pauseKeyListener) {
                    return;
                }
                pauseKeyListener = self.jsPsych.pluginAPI.getKeyboardResponse({
                    callback_function: function () {
                        end_trial();
                    },
                    valid_responses: ['n', 'N'],
                    rt_method: 'performance',
                    persist: false,
                    allow_held_key: false,
                });
            }

            function teardownPauseKey() {
                if (!pauseKeyListener) {
                    return;
                }
                self.jsPsych.pluginAPI.cancelKeyboardResponse(pauseKeyListener);
                pauseKeyListener = null;
            }

            function setupFeedbackKey() {
                if (!trial.pause_each_stage) {
                    return;
                }
                if (feedbackKeyListener) {
                    return;
                }
                feedbackKeyListener = self.jsPsych.pluginAPI.getKeyboardResponse({
                    callback_function: function () {
                        ctx.clearRect(0, 0, canvas.width, canvas.height);
                        ctx.canvas.remove()
                        self.jsPsych.pluginAPI.clearAllTimeouts();
                        self.jsPsych.finishTrial(trial_data);
                    },
                    valid_responses: ['n', 'N'],
                    rt_method: 'performance',
                    persist: false,
                    allow_held_key: false,
                });
            }

            function teardownFeedbackKey() {
                if (!feedbackKeyListener) {
                    return;
                }
                self.jsPsych.pluginAPI.cancelKeyboardResponse(feedbackKeyListener);
                feedbackKeyListener = null;
            }

            function end_trial() {
                if (endtrial) {
                    return;
                }
                endtrial = true;
                teardownPauseKey();
                teardownFeedbackKey();
                // Cancel orientation bar animation if active
                if (trial._orientationBarAnimationId !== undefined) {
                    cancelAnimationFrame(trial._orientationBarAnimationId);
                }

                if (!Array.isArray(pastYcoords)) {
                    pastYcoords = [];
                }
                if (!Array.isArray(pastXcoords)) {
                    pastXcoords = [];
                }
                if (trial.response_type !== 'orientation_bar') {
                    // Check for start out of center
                    for (var ii = 0; ii < pastYcoords.length; ii++){
                        if (pastYcoords[ii] != 0 || pastXcoords[ii] != 0){
                            break
                        }
                    }
                    if (pastYcoords.length > 0 &&
                        Math.sqrt( pastYcoords[ii] * pastYcoords[ii] + pastXcoords[ii] * pastXcoords[ii] ) > startingradius ){
                        startoutofCenter[0] = true;
                    }
                }

                // ctx.clearRect(0, 0, canvas.width, canvas.height);
                if (mousecheckinterval) {
                    clearInterval(mousecheckinterval);
                }
                ctx.font = "20px Arial";
                if (trial.draw_wheel){
                    var wait_time = 1000
                    if (toofast[0] == true ||
                        tooslow[0] == true ||
                        startoutofCenter[0] == true ){
                            wait_time = wait_time * 4
                        }

                    // Build Feedback Options
                    var txt = ''

                    if (trial.response_type !== 'orientation_bar') {
                        if (startoutofCenter[0]){txt = 'Response Started Out Of Center.'}
                        if (toofast[0]){txt = 'Too Fast Leaving The Center.'}
                        if (tooslow[0]){txt = 'Too Slow Leaving The Center.'}
                    } else {
                        if (toofast[0]){txt = 'Too Fast Clicking.'}
                    }

                    if (timeout[0] == true){
                        ctx.textAlign = "center";
                        ctx.fillStyle = "red";
                        ctx.fillText('Time Penalty:', midx, canvas.height * .6);
                        ctx.fillText('Trial Timed Out.', midx, canvas.height * .65);
                        display_element.insertBefore(canvas, null);
                    } else if (txt != '') {
                        ctx.textAlign = "center";
                        ctx.fillStyle = 'red';
                        ctx.fillText('Time Penalty:', midx, canvas.height * .6);
                        ctx.fillText(txt, midx, canvas.height * .65)
                        display_element.insertBefore(canvas, null);
                    }

                    if (trial.pause_each_stage) {
                        setupFeedbackKey();
                    } else {
                        setTimeout(() => {
                            // console.log('trial data triggered')
                            ctx.clearRect(0, 0, canvas.width, canvas.height);
                            ctx.canvas.remove()
                            self.jsPsych.pluginAPI.clearAllTimeouts();
                            self.jsPsych.finishTrial(trial_data);
                        }, wait_time);
                    }

                } else {
                    // document.getElementById("jspsych-button-group").remove()
                    ctx.clearRect(0, 0, canvas.width, canvas.height);
                    ctx.canvas.remove()
                    self.jsPsych.finishTrial(trial_data);
                }

            }
            

            if (trial.draw_wheel == true & endtrial == false){

                // Check response type for mouse interaction
                if (trial.response_type === 'orientation_bar') {
                    // ============================================================
                    // ORIENTATION BAR RESPONSE: Mouse up/down rotation
                    // ============================================================
                    
                    // Initialize orientation tracking
                    if (trial.current_orientation === undefined) {
                        trial.current_orientation = 0; // Start at 0°
                    }
                    
                    var lastMouseY = null;
                    var rotationSpeed = 0.3; // Degrees per pixel of vertical mouse movement
                    
                    // Track mouse Y position for rotation (up/down movement)
                    // Rotation happens on mouse movement (no button press needed)
                    canvas.addEventListener("mousemove", function(e) {
                        var currentY = e.offsetY;
                        
                        // Rotate bar based on vertical mouse movement
                        if (lastMouseY !== null) {
                            var deltaY = currentY - lastMouseY;
                            // Up (negative deltaY) = CCW (increase angle)
                            // Down (positive deltaY) = CW (decrease angle)
                            trial.current_orientation -= deltaY * rotationSpeed;
                            
                            // Wrap orientation to 0-180° range
                            while (trial.current_orientation < 0) {
                                trial.current_orientation += 180;
                            }
                            while (trial.current_orientation >= 180) {
                                trial.current_orientation -= 180;
                            }
                        }
                        
                        lastMouseY = currentY;
                    }.bind(this));
                    
                    // Click: confirm response
                    canvas.addEventListener("click", function(e) {
                        if (responded == false) {
                            responded = true;
                            // Response RT
                            var response_time = performance.now() - start_time;
                            rt.push(response_time);
                            if (response_time <= startinitiatetime) {
                                toofast[0] = true;
                            }
                            
                            // Record orientation response (0-180°)
                            var response_orientation = trial.current_orientation;
                            degrees.push(response_orientation);
                            radians.push(response_orientation * Math.PI / 180);
                            
                            // Calculate error (difference from target orientation)
                            var target_orientation = trial.orientations[targetN];
                            var error = response_orientation - target_orientation;
                            
                            // Wrap error to -90 to +90 range (shortest path)
                            if (error > 90) {
                                error = error - 180;
                            } else if (error < -90) {
                                error = error + 180;
                            }
                            
                            resp_error.push(error);
                            derotated_degrees.push(response_orientation); // For compatibility
                            
                            // Draw feedback
                            this.drawOrientationBarFeedback(ctx, trial, midx, midy, targetN, indiv_patch_radius, response_orientation, target_orientation);
                            
                            // Calculate points (100 - error percentage)
                            points.push(100 - Math.round(Math.abs(error) / 90 * 100));
                            
                            finished = true;
                            end_trial();
                        }
                    }.bind(this));
                    
                    // Continuous redraw for smooth rotation
                    var animationFrameId;
                    var self = this;
                    function animateOrientationBar() {
                        if (!finished && !endtrial) {
                            ctx.clearRect(0, 0, canvas.width, canvas.height);
                            // Redraw orientation bar
                            self.drawOrientationBarResponse(ctx, trial, midx, midy, targetN, indiv_patch_radius);
                            animationFrameId = requestAnimationFrame(animateOrientationBar);
                        }
                    }
                    animateOrientationBar();
                    
                    // Store animation frame ID for cleanup in end_trial
                    trial._orientationBarAnimationId = animationFrameId;
                    
                } else {
                    // ============================================================
                    // COLOR WHEEL RESPONSE: Original mouse interaction
                    // ============================================================
                    
                    canvas.addEventListener("mousemove", function(e) {
                        x_mouse = e.offsetX - canvas.width/2;
                        y_mouse = canvas.height/2 - e.offsetY;
                    });

                    function checkMousePosition() {
                    pastXcoords.push(x_mouse);
                    pastYcoords.push(y_mouse);
                    interval_count += 1
                    
                    // Include checks on every interval
                    if (trial.draw_wheel == true){
                        var distance = Math.sqrt(x_mouse * x_mouse + y_mouse * y_mouse)
                        // Check for time out
                        if ( performance.now() - start_time > maxtime & timeout[0] == false){
                            timeout[0] = true
                            // console.log('timeout1')
                        }
                        // Check for too fast/slow
                        if (distance >= startingradius & leavecenter == false){
                            
                            leavecenter = true;
                            console.log('leaving', leavecenter)
                            leavecenterRT.push(performance.now() - start_time);

                            if (Math.round( performance.now() - start_time ) <= startinitiatetime & toofast[0] == false){
                                toofast[0] = true;
                                console.log('fast')
                            }
                            else if (Math.round( performance.now() - start_time ) >= maxinitiatetime & tooslow[0] == false){
                                tooslow[0] = true;
                                console.log('slow')
                            }   
                        } // Too fast/slow end

                        if (interval_count == interval){
                            interval_count = 0
                            var coor = "(" + x_mouse + "," + y_mouse + ")";
                            mouse_coords.push(coor);
                            mouse_coord_rts.push( Math.round( performance.now() - start_time ) );
                            
                        }

                        // Check for response
                        if (distance >= inner_radius & responded == false){
                            if (responded == false){
                                for (var ii = 0; ii < trial.patch_positionalangle.length; ii++){
                                    var patches = new Path2D();
                                    patches.arc(midx + patchradius * Math.cos( trial.patch_positionalangle[ii] * Math.PI/180 ), 
                                                midy + patchradius * Math.sin( trial.patch_positionalangle[ii] * Math.PI/180 ), 
                                                indiv_patch_radius+1, 0, 2 * Math.PI);
                                    var rgbstr = 'rgb(20, 20, 20)'
                                    ctx.strokeStyle = rgbstr
                                    ctx.fillStyle   = rgbstr
                                    ctx.fill(patches);
                                    ctx.stroke(patches);
                                    display_element.insertBefore(canvas, null); 
                                }
                            }
                            
                            responded = true
                            // Response RT
                            rt.push(performance.now() - start_time);
                            // Response Degrees (with rotation)
                            var rad = 2 * Math.atan( y_mouse / ( x_mouse + Math.sqrt( x_mouse * x_mouse + y_mouse * y_mouse ) ) )
                            
                            degrees.push(rad * (180/ Math.PI))
                            radians.push(rad)
                            // Response Degrees (without rotation)
                            if (degrees[0] > 0){
                                degrees[0] = Math.abs(degrees[0] - 180) + 180;
                            }
                            if (degrees[0] < 0){
                                degrees[0] = Math.abs(degrees[0]);
                            }
                            derotated_degrees.push(degrees[0] - Number(trial.wheel_rotation))
                            if (derotated_degrees[0] < 0){ derotated_degrees[0] += 360 }
                            else if (derotated_degrees[0] > 360){ derotated_degrees[0] -= 360 }

                            resp_error.push( derotated_degrees[0] - trial.choice_colorangles[targetN])
                            if (resp_error[0] < -180 ){ resp_error[0] = Math.abs( Math.abs(resp_error[0]) - 360 ) }
                            if (resp_error[0] >  180 ){ resp_error[0] = resp_error[0] - 360 }

                            // Draw Response Angle
                            ctx.strokeStyle = 'white'
                            ctx.beginPath();
                            ctx.moveTo(midx + outer_radius * 1.1 * Math.cos(-radians[0]), midy + outer_radius * 1.1 * Math.sin(-radians[0]) )
                            ctx.lineTo(midx + inner_radius * Math.cos(-radians[0]), midy + inner_radius * Math.sin(-radians[0]) )
                            ctx.stroke();
                            ctx.closePath();

                            // Draw the Correct Location
                            ctx.strokeStyle = 'lime'
                            ctx.beginPath();
                            var cr = trial.choice_colorangles[targetN] + Number(trial.wheel_rotation)
                            if (cr < 0){cr += 359}
                            if (cr > 359){cr -= 359}
                            cr = cr * Math.PI/180
                            ctx.moveTo(midx + outer_radius * 1.1 * Math.cos(cr), midy + outer_radius * 1.1 * Math.sin(cr) )
                            ctx.lineTo(midx + inner_radius * Math.cos(cr), midy + inner_radius * Math.sin(cr) )
                            ctx.stroke();
                            ctx.closePath();


                            // Join the Response and Correct locaitons by an arc
                            let startAngle = -radians[0];
                            let endAngle = cr;
                            startAngle = (startAngle + 2 * Math.PI) % (2 * Math.PI);
                            endAngle = (endAngle + 2 * Math.PI) % (2 * Math.PI);
                            let angleDiff = endAngle - startAngle;
                            if (Math.abs(angleDiff) > Math.PI) {
                                if (angleDiff > 0) {
                                    // If endAngle is greater, go counterclockwise
                                    angleDiff = angleDiff - 2 * Math.PI;
                                } else {
                                    // If startAngle is greater, go clockwise
                                    angleDiff = 2 * Math.PI + angleDiff;
                                }
                            }
                            let counterclockwise = angleDiff < 0;
                            ctx.beginPath();
                            ctx.arc(midx, midy, outer_radius * 1.1, startAngle, endAngle, counterclockwise);
                            ctx.stroke();
                            ctx.closePath();
                            display_element.insertBefore(canvas, null);

                            points.push( 100 - Math.round( Math.abs(resp_error) / 180 * 100, 2 ) )

                            finished = true
                            end_trial()
                            
                        } 
                    }
                }
                    mousecheckinterval = setInterval(checkMousePosition, interval);
                } // End else (color wheel response)
            } // End if (trial.draw_wheel == true)

            

            const safeChoiceColors = Array.isArray(trial.choice_colors) ? trial.choice_colors : [];
            const safeChoiceAngles = Array.isArray(trial.choice_colorangles) ? trial.choice_colorangles : [];
            const safePatchAngles = Array.isArray(trial.patch_positionalangle) ? trial.patch_positionalangle : [];
            const safeTargetIndex = (typeof targetN === 'number' && safeChoiceColors.length > targetN) ? targetN : null;

            var trial_data = {
                // Task Variables
                num_items: safeChoiceColors.length,
                target_color: safeTargetIndex !== null ? safeChoiceColors[safeTargetIndex] : null,
                target_angle_norotation: safeTargetIndex !== null ? safeChoiceAngles[safeTargetIndex] : null,
                rotation: trial.wheel_rotation,
                redundancy: trial.redundancy,

                // Initial Precision Judgement 
                response_radians: radians,
                response_degrees: degrees,
                
                response_derotated_degress: derotated_degrees,
                response_error_deg: resp_error,
                response_RT: rt,
                leave_center_RT: leavecenterRT,

                points: points,

                too_slow_trigger: tooslow,
                too_fast_trigger: toofast,
                started_outof_center: startoutofCenter,
                timeout: timeout,

                mouse_movement_rt: mouse_coord_rts,
                mouse_movement_coords: mouse_coords,

                target_patchN: safeTargetIndex !== null ? safeTargetIndex + 1 : null,
                all_patch_angles: safeChoiceAngles,
                all_patch_colors: safeChoiceColors,
                patch_angles_from_center: safePatchAngles,
                patch_imaginary_circle: patchradius,
                patch_indiv_size_radius: indiv_patch_radius,
                outer_wheel_radius: outer_radius,
                inner_wheel_radius: inner_radius,
                wheel_canvas_height_width: [canvas.height, canvas.width],
            };

        }
    }
    ConfidenceWheelPlugin.info = info;
  
    return ConfidenceWheelPlugin;
  
  })(jsPsychModule);