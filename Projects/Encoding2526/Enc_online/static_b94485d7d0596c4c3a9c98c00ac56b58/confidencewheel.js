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
            show_noise_mask:{
                type: jspsych.ParameterType.BOOL,
                pretty_name: "Show Noise Mask",
                default: false,  // Show per-item noise mask (for Sub-Experiment 1 retention interval)
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
            stimulus_scale: {
                type: jspsych.ParameterType.FLOAT,
                pretty_name: "Stimulus Scale",
                default: 1.0,  // Scale for stimulus size (patchradius and patch size)
            },
            noise_mask_scale: {
                type: jspsych.ParameterType.FLOAT,
                pretty_name: "Noise Mask Scale",
                default: 1.2,  // Noise mask radius relative to stimulus patch radius
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
            this._maskIndex = 0;
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
            var barLength = 3 * patchRadius;
            // Bar width calculated to match visual area of color patch circle
            var barWidth = barLength / 3;
            
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

        generateNoiseCanvas(diameterPx) {
            const canvas = document.createElement("canvas");
            canvas.width = diameterPx;
            canvas.height = diameterPx;
            const ctx = canvas.getContext("2d");
            const img = ctx.createImageData(diameterPx, diameterPx);
            const data = img.data;
            for (let i = 0; i < data.length; i += 4) {
                const noise = Math.floor(128 + (Math.random() * 2 - 1) * 64);
                data[i] = noise;
                data[i + 1] = noise;
                data[i + 2] = noise;
                data[i + 3] = 255;
            }
            ctx.putImageData(img, 0, 0);
            return canvas;
        }

        drawNoiseMaskDisks(ctx, trial, centerX, centerY, patchradius, patchRadius) {
            /**
             * Draw per-item noise masks (slightly larger than stimulus patches).
             * Matches the Matlab mask: noisy disk overlay on each item.
             */
            const scale = (typeof trial.noise_mask_scale === 'number' && !isNaN(trial.noise_mask_scale))
                ? trial.noise_mask_scale
                : 1.3;
            const maskRadius = patchRadius * scale;
            const diameter = Math.ceil(maskRadius * 2);

            for (let ii = 0; ii < trial.patch_positionalangle.length; ii++) {
                const posAngle = trial.patch_positionalangle[ii] * Math.PI / 180;
                const maskCenterX = centerX + patchradius * Math.cos(posAngle);
                const maskCenterY = centerY + patchradius * Math.sin(posAngle);
                const noiseCanvas = this.generateNoiseCanvas(diameter);

                ctx.save();
                ctx.beginPath();
                ctx.arc(maskCenterX, maskCenterY, maskRadius, 0, 2 * Math.PI);
                ctx.fillStyle = 'black';
                ctx.fill();
                ctx.clip();
                ctx.drawImage(noiseCanvas, maskCenterX - maskRadius, maskCenterY - maskRadius);
                ctx.restore();
            }
        }

        drawOrientationBarResponse(ctx, trial, centerX, centerY, targetN, patchRadius, wheelRadius, wheelWidth, lineExtension, lineThickness) {
            /**
             * Draw orientation bar response interface for Sub-Experiment 3
             * 
             * Draws:
             * - Gray response wheel (donut shape)
             * - 8 orientation line markers (0°, 45°, 90°, 135°, 180°, 225°, 270°, 315°)
             * - Colored orientation bar at center
             * Mouse position rotates the bar, click confirms response
             */
            
            // Bar dimensions
            var barLength = 3 * patchRadius;
            var barWidth = barLength / 2.86;
            
            // Get target color (bar color matches target item)
            var targetColor = trial.choice_colors[targetN];
            var rgbstr = 'rgb(' + targetColor[0] + ',' + targetColor[1] + ',' + targetColor[2] + ')';
            
            // Initial orientation (will be updated by mouse movement)
            if (trial.current_orientation === undefined) {
                trial.current_orientation = 0; // Start at 0°
            }
            
            // Draw gray response wheel (donut/ring shape) - draw outer circle filled, then inner circle on top in black
            ctx.save();
            // Draw outer gray circle
            ctx.fillStyle = 'rgb(128, 128, 128)';
            ctx.beginPath();
            ctx.arc(centerX, centerY, wheelRadius, 0, 2 * Math.PI);
            ctx.fill();
            
            // Draw inner black circle on top to create donut
            ctx.fillStyle = 'black';
            ctx.beginPath();
            ctx.arc(centerX, centerY, wheelRadius - wheelWidth, 0, 2 * Math.PI);
            ctx.fill();
            ctx.restore();
            
            // Draw 8 orientation line markers
            ctx.save();
            ctx.strokeStyle = 'rgb(200, 200, 200)'; // Light gray lines
            ctx.lineWidth = lineThickness;
            
            for (var i = 0; i < 8; i++) {
                var angle = (i * 45) * Math.PI / 180; // 0°, 45°, 90°, etc.
                
                // Inner point (on outer edge of wheel ring)
                var innerX = centerX + (wheelRadius - wheelWidth) * Math.cos(angle);
                var innerY = centerY + (wheelRadius - wheelWidth) * Math.sin(angle);
                
                // Outer point (extends beyond wheel)
                var outerX = centerX + (wheelRadius + lineExtension) * Math.cos(angle);
                var outerY = centerY + (wheelRadius + lineExtension) * Math.sin(angle);
                
                // Draw line
                ctx.beginPath();
                ctx.moveTo(innerX, innerY);
                ctx.lineTo(outerX, outerY);
                ctx.stroke();
            }
            ctx.restore();

            // Draw center circle for penalty reference
            if (typeof trial._startingradius === 'number') {
                ctx.save();
                const centerCircle = new Path2D();
                centerCircle.arc(centerX, centerY, trial._startingradius, 0, 2 * Math.PI);
                ctx.strokeStyle = 'white';
                ctx.lineWidth = 1;
                ctx.stroke(centerCircle);
                ctx.restore();
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
        }

        drawOrientationBarFeedback(ctx, trial, centerX, centerY, targetN, patchRadius, responseOrientation, targetOrientation, responseAngle360, targetAngle360, wheelRadius, wheelWidth, lineExtension, lineThickness) {
            /**
             * Draw feedback for orientation bar response
             * Shows response orientation (white bar) and correct orientation (green bar)
             * Includes error arc on the response wheel showing minimum angle distance (0-180° symmetry)
             * Matches Subexp1/2 radial line and arc style
             */
            
            var barLength = 3 * patchRadius;
            var barWidth = barLength / 2.86;
            var targetColor = trial.choice_colors[targetN];
            
            // Redraw the gray response wheel (donut shape)
            ctx.save();
            ctx.fillStyle = 'rgb(128, 128, 128)';
            ctx.beginPath();
            ctx.arc(centerX, centerY, wheelRadius, 0, 2 * Math.PI);
            ctx.fill();
            
            ctx.fillStyle = 'black';
            ctx.beginPath();
            ctx.arc(centerX, centerY, wheelRadius - wheelWidth, 0, 2 * Math.PI);
            ctx.fill();
            ctx.restore();
            
            // Redraw 8 orientation line markers
            ctx.save();
            ctx.strokeStyle = 'rgb(200, 200, 200)';
            ctx.lineWidth = lineThickness;
            
            for (var i = 0; i < 8; i++) {
                var angle = (i * 45) * Math.PI / 180;
                var innerX = centerX + (wheelRadius - wheelWidth) * Math.cos(angle);
                var innerY = centerY + (wheelRadius - wheelWidth) * Math.sin(angle);
                var outerX = centerX + (wheelRadius + lineExtension) * Math.cos(angle);
                var outerY = centerY + (wheelRadius + lineExtension) * Math.sin(angle);
                
                ctx.beginPath();
                ctx.moveTo(innerX, innerY);
                ctx.lineTo(outerX, outerY);
                ctx.stroke();
            }
            ctx.restore();
            
            // Convert display angles (0-360) to radians for wheel lines/arc
            var responseAngleRad = responseAngle360 * Math.PI / 180;
            var targetAngleRad = targetAngle360 * Math.PI / 180;
            
            // Draw radial lines from inner wheel edge to past outer edge (like Subexp1/2)
            var arcRadius = wheelRadius + lineExtension; // Arc drawn outside wheel
            
            // Response orientation line (white) - from inner edge to beyond outer edge
            ctx.save();
            ctx.strokeStyle = 'white';
            ctx.lineWidth = 3;
            ctx.beginPath();
            ctx.moveTo(centerX + (wheelRadius - wheelWidth) * Math.cos(responseAngleRad), 
                       centerY + (wheelRadius - wheelWidth) * Math.sin(responseAngleRad));
            ctx.lineTo(centerX + arcRadius * Math.cos(responseAngleRad), 
                       centerY + arcRadius * Math.sin(responseAngleRad));
            ctx.stroke();
            ctx.restore();
            
            // Target orientation line (green) - from inner edge to beyond outer edge
            ctx.save();
            ctx.strokeStyle = 'lime';
            ctx.lineWidth = 3;
            ctx.beginPath();
            ctx.moveTo(centerX + (wheelRadius - wheelWidth) * Math.cos(targetAngleRad), 
                       centerY + (wheelRadius - wheelWidth) * Math.sin(targetAngleRad));
            ctx.lineTo(centerX + arcRadius * Math.cos(targetAngleRad), 
                       centerY + arcRadius * Math.sin(targetAngleRad));
            ctx.stroke();
            ctx.restore();

            // Dashed green radial line from center to target direction
            ctx.save();
            ctx.strokeStyle = 'lime';
            ctx.lineWidth = 3;
            ctx.setLineDash([6, 6]);
            ctx.beginPath();
            ctx.moveTo(centerX, centerY);
            ctx.lineTo(centerX + arcRadius * Math.cos(targetAngleRad),
                       centerY + arcRadius * Math.sin(targetAngleRad));
            ctx.stroke();
            ctx.restore();
            
            // Draw error arc between response and target on the wheel (outside the wheel ring)
            // Use 0-360° display angles and draw the shorter arc
            var angleDiff360 = ((responseAngle360 - targetAngle360 + 540) % 360) - 180;
            if (angleDiff360 !== 0) {
                var counterClockwise = angleDiff360 < 0;
                ctx.save();
                ctx.strokeStyle = 'red';
                ctx.lineWidth = 3;
                ctx.beginPath();
                ctx.arc(centerX, centerY, arcRadius, targetAngleRad, responseAngleRad, counterClockwise);
                ctx.stroke();
                ctx.restore();
            }
            
            // Draw response orientation bar at center (keep target color)
            var responseRgb = 'rgb(' + targetColor[0] + ',' + targetColor[1] + ',' + targetColor[2] + ')';
            ctx.save();
            ctx.translate(centerX, centerY);
            ctx.rotate(responseOrientation * Math.PI / 180);
            ctx.fillStyle = responseRgb;
            ctx.strokeStyle = responseRgb;
            ctx.lineWidth = 2;
            ctx.fillRect(-barLength/2, -barWidth/2, barLength, barWidth);
            ctx.strokeRect(-barLength/2, -barWidth/2, barLength, barWidth);
            ctx.restore();
            
            // Draw target orientation bar at center (green outline)
            ctx.save();
            ctx.translate(centerX, centerY);
            ctx.rotate(targetOrientation * Math.PI / 180);
            ctx.strokeStyle = 'lime';
            ctx.lineWidth = 2;
            var outlineScale = 1.10;
            var outlineLength = barLength * outlineScale;
            var outlineWidth = barWidth * outlineScale;
            ctx.strokeRect(-outlineLength/2, -outlineWidth/2, outlineLength, outlineWidth);
            ctx.restore();
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
            var barLength = 2 * barRadius * 0.7;
            var barWidth = barLength * (1 / 7);
            
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
            
            var maskDataList = this._maskCache;
            const scale = (typeof trial.mask_scale === 'number' && !isNaN(trial.mask_scale))
                ? trial.mask_scale
                : 1;
            const scaledBarRadius = barRadius * scale;
            
            // Use pre-generated mask data if available, otherwise generate 5 per session
            if (!Array.isArray(maskDataList) || maskDataList.length === 0) {
                var numBars = 5000;
                maskDataList = [];
                for (var m = 0; m < 5; m++) {
                    maskDataList.push(this.generateVisualMask(centerX, centerY, maskRadius, scaledBarRadius, numBars));
                }
                this._maskCache = maskDataList;
            }

            var maskData = maskDataList[this._maskIndex % maskDataList.length];
            this._maskIndex += 1;
            
            // Bar dimensions (same as stimulus bars)
            var barLength = 2 * scaledBarRadius * 0.7;
            var barWidth = barLength / 3;
            
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
            const viewportHeight = (typeof window.innerHeight === 'number' && !isNaN(window.innerHeight))
                ? window.innerHeight
                : window.outerHeight;
            const viewportWidth = (typeof window.innerWidth === 'number' && !isNaN(window.innerWidth))
                ? window.innerWidth
                : window.outerWidth;
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
            ctx.canvas.width  = viewportWidth * 0.95;
            ctx.canvas.height = viewportHeight * 0.95;
            
            // Central penalty circle radius (for mouse start position)
            var startingradius;
            if (window.pxPerMm) {
                var desired_starting_radius_mm = 7.8; // 7.8mm radius for central circle
                startingradius = Math.round(window.pxPerMm * desired_starting_radius_mm);
            } else {
                startingradius = Math.round(ctx.canvas.height * 0.035); // fallback
            }
            trial._startingradius = startingradius;
            var basePatchRadius;
            if (window.pxPerMm) {
                // Invisible circle radius: 4.5 degrees VA (~22.5mm at calibrated viewing distance)
                // For Subexp3 (orientation bars), use larger radius for better spacing
                var desired_circle_radius_mm = (trial.stimulus_type === 'orientation_bars') ? 25.0 : 22.5;
                basePatchRadius = Math.round(window.pxPerMm * desired_circle_radius_mm);
            } else {
                basePatchRadius = ctx.canvas.height * 0.1; // fallback: ~10% of canvas height
            }
            var baseIndivPatchRadius;
            if (window.pxPerMm) {
                // desired radius in millimeters (changeable)
                var desired_patch_radius_mm = 5; // 5 mm radius => 10 mm diameter
                baseIndivPatchRadius = Math.round(window.pxPerMm * desired_patch_radius_mm);
            } else {
                baseIndivPatchRadius = Math.round(ctx.canvas.height * 0.024);
            }
            var stimulusScale = (typeof trial.stimulus_scale === 'number' && !isNaN(trial.stimulus_scale))
                ? trial.stimulus_scale
                : 1.0;
            // Invisible circle should NOT be scaled - it must maintain calibrated physical size
            var patchradius = basePatchRadius;
            // Individual stimulus size CAN be scaled for visual design (e.g., orientation bars)
            var indiv_patch_radius = Math.round(baseIndivPatchRadius * stimulusScale);
            
            //  Add central white circle for mouse centering
            var midx = ctx.canvas.width/2
            var midy = ctx.canvas.height/2
            const circle = new Path2D();
            circle.arc(midx, midy, startingradius, 0, 2 * Math.PI);
            ctx.strokeStyle = 'white';
            ctx.border = 'thick';
            ctx.stroke(circle);
            // Always attach canvas; response type decides what is drawn on it
            display_element.insertBefore(canvas, null);
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
                
                // Check if showing per-item noise mask (Sub-Experiment 1 retention interval)
                if (trial.show_noise_mask === true) {
                    this.drawNoiseMaskDisks(ctx, trial, midx, midy, patchradius, indiv_patch_radius);
                    display_element.insertBefore(canvas, null);
                }
                // Check if showing visual mask (for Sub-Experiment 3 retention interval)
                else if (trial.show_mask == true) {
                    // Mask radius = 1.3 * invisible circle radius for Subexp3
                    var maskRadius = patchradius * 1.3;
                    
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
                    
                    
                
                    // Draw Color Wheel - size follows calibration
                    var outer_radius, inner_radius;
                    if (window.pxPerMm) {
                        var desired_wheel_outer_radius_mm = 45; // Outer edge of color wheel
                        var desired_wheel_width_mm = 6; // Width of the wheel ring
                        outer_radius = Math.round(window.pxPerMm * desired_wheel_outer_radius_mm);
                        inner_radius = Math.round(outer_radius - window.pxPerMm * desired_wheel_width_mm);
                    } else {
                        outer_radius = Math.round(ctx.canvas.height * 0.230);
                        inner_radius = Math.round(outer_radius - ctx.canvas.height * 0.026);
                    }

                    
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

            var leaveCenterTooFastMs = 150;
            var responseTooFastMs = 400;
            var leaveCenterTooSlowMs = 4000;
            var responseTooSlowMs = 4000;

            var toofast = [false];
            var tooslow = [false];
            var timeout = [false];
            var startoutofCenter = [false]; 

            var leavecenter = false;  
            var responded = false;

            var resp_error = []
            var rt = []
            var response_rt_from_start = []
            var degrees = []
            var radians = []
            var derotated_degrees = []
            var response_angle_360_saved = null;
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
                if (trial._orientationMouseInterval) {
                    clearInterval(trial._orientationMouseInterval);
                }

                if (!Array.isArray(pastYcoords)) {
                    pastYcoords = [];
                }
                if (!Array.isArray(pastXcoords)) {
                    pastXcoords = [];
                }
                // Check for start out of center (same logic for all response types)
                for (var ii = 0; ii < pastYcoords.length; ii++){
                    if (pastYcoords[ii] != 0 || pastXcoords[ii] != 0){
                        break
                    }
                }
                if (pastYcoords.length > 0 &&
                    Math.sqrt( pastYcoords[ii] * pastYcoords[ii] + pastXcoords[ii] * pastXcoords[ii] ) > startingradius ){
                    startoutofCenter[0] = true;
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
                        if (toofast[0]){txt = 'Left Center Circle Too Quickly'}
                        if (tooslow[0]){txt = 'Responded Too Slowly'}
                    } else {
                        if (startoutofCenter[0]){txt = 'Response Started Out Of Center.'}
                        if (toofast[0]){txt = 'Left Center Circle Too Quickly'}
                        if (tooslow[0]){txt = 'Responded Too Slowly'}
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
                            // RT consistency check (runtime diagnostics)
                            console.log('[RT-CHECK]', {
                                response_type: trial.response_type || 'color_wheel',
                                response_RT: trial_data.response_RT,
                                response_RT_from_start: trial_data.response_RT_from_start,
                                leave_center_RT: trial_data.leave_center_RT,
                                too_fast_trigger: trial_data.too_fast_trigger,
                                too_slow_trigger: trial_data.too_slow_trigger,
                                started_outof_center: trial_data.started_outof_center
                            });
                            ctx.clearRect(0, 0, canvas.width, canvas.height);
                            ctx.canvas.remove()
                            self.jsPsych.pluginAPI.clearAllTimeouts();
                            self.jsPsych.finishTrial(trial_data);
                        }, wait_time);
                    }

                } else {
                    // document.getElementById("jspsych-button-group").remove()
                    // RT consistency check (runtime diagnostics)
                    console.log('[RT-CHECK]', {
                        response_type: trial.response_type || 'color_wheel',
                        response_RT: trial_data.response_RT,
                        response_RT_from_start: trial_data.response_RT_from_start,
                        leave_center_RT: trial_data.leave_center_RT,
                        too_fast_trigger: trial_data.too_fast_trigger,
                        too_slow_trigger: trial_data.too_slow_trigger,
                        started_outof_center: trial_data.started_outof_center
                    });
                    ctx.clearRect(0, 0, canvas.width, canvas.height);
                    ctx.canvas.remove()
                    self.jsPsych.finishTrial(trial_data);
                }

            }
            

            if (trial.draw_wheel == true & endtrial == false){

                // Check response type for mouse interaction
                if (trial.response_type === 'orientation_bar') {
                    // ============================================================
                    // ORIENTATION BAR RESPONSE: Mouse position rotates bar
                    // ============================================================
                    
                    // Calculate response wheel dimensions (same as color wheel)
                    var wheelOuter, wheelInner;
                    if (window.pxPerMm) {
                        var desired_wheel_outer_radius_mm = 45;
                        var desired_wheel_width_mm = 6;
                        wheelOuter = Math.round(window.pxPerMm * desired_wheel_outer_radius_mm);
                        wheelInner = Math.round(wheelOuter - window.pxPerMm * desired_wheel_width_mm);
                    } else {
                        wheelOuter = Math.round(ctx.canvas.height * 0.230);
                        wheelInner = Math.round(wheelOuter - ctx.canvas.height * 0.026);
                    }
                    var wheelWidth = wheelOuter - wheelInner;
                    // Sync with trial_data fields used for logging
                    outer_radius = wheelOuter;
                    inner_radius = wheelInner;
                    var lineExtension = 10; // pixels beyond wheel
                    var lineThickness = 3; // pixels
                    
                    // Initialize orientation tracking
                    if (trial.current_orientation === undefined) {
                        trial.current_orientation = null; // Will be set on first mouse move
                    }
                    
                    var leavecenter = false;
                    var leftcentertime = 0;
                    
                    // Track mouse position for orientation calculation
                    var x_mouse = 0;
                    var y_mouse = 0;
                    var prev_distance = null;
                    var hasFirstMove = false;
                    var orientationSampleCount = 0;
                    var orientationMouseInterval;
                    
                    canvas.addEventListener("mousemove", function(e) {
                        x_mouse = e.offsetX - canvas.width/2;
                        y_mouse = canvas.height/2 - e.offsetY;
                        pastXcoords.push(x_mouse);
                        pastYcoords.push(y_mouse);
                        
                        // Check center circle constraints
                        var distance = Math.sqrt(x_mouse * x_mouse + y_mouse * y_mouse);
                        
                        if (distance >= startingradius && leavecenter == false) {
                            leavecenter = true;
                            leftcentertime = performance.now() - start_time;
                            leavecenterRT.push(leftcentertime);
                        }

                        if (!hasFirstMove) {
                            hasFirstMove = true;
                            if (distance > startingradius) {
                                startoutofCenter[0] = true;
                            }
                        }
                        
                        // Calculate bar orientation from cursor position
                        // Use atan2 to get angle from center to mouse cursor
                        // Note: y_mouse is already inverted (canvas.height/2 - e.offsetY), so use negative for correct direction
                        var angleRad = Math.atan2(-y_mouse, x_mouse);
                        var angleDeg360 = angleRad * 180 / Math.PI;
                        if (angleDeg360 < 0) angleDeg360 += 360;
                        
                        // Convert to 0-180° range (orientation is symmetric)
                        var angleDeg = angleDeg360 % 180;
                        
                        // Initialize orientation on first mouse move to prevent jump
                        if (trial.current_orientation === null) {
                            trial.current_orientation = angleDeg;
                        }
                        
                        trial.current_orientation = angleDeg;
                        
                        // RESPONSE CONFIRMATION: Register response when cursor hits the wheel (like Subexp1/2)
                        // Robust to very fast movement: if we cross the wheel band between samples, count it as a hit
                        var crossedWheelBand = false;
                        if (prev_distance !== null) {
                            crossedWheelBand = Math.min(prev_distance, distance) <= wheelOuter &&
                                               Math.max(prev_distance, distance) >= wheelInner;
                        }
                        if (responded == false && (distance >= wheelInner && distance <= wheelOuter || crossedWheelBand)) {
                            // Check response time
                            var response_time = performance.now() - start_time;
                            var movement_rt = leavecenterRT.length ? (response_time - leavecenterRT[0]) : response_time;
                            
                            if (startoutofCenter[0]) {
                                leavecenterRT[0] = null;
                                toofast[0] = false;
                                tooslow[0] = false;
                            } else {
                                if (leavecenterRT.length && leavecenterRT[0] < leaveCenterTooFastMs) {
                                    toofast[0] = true;
                                }
                                if (response_time < responseTooFastMs) {
                                    toofast[0] = true;
                                }
                                if (leavecenterRT.length && leavecenterRT[0] > leaveCenterTooSlowMs) {
                                    tooslow[0] = true;
                                }
                                if (response_time > responseTooSlowMs) {
                                    tooslow[0] = true;
                                }
                            }
                            
                            responded = true;
                            rt.push(movement_rt);
                            response_rt_from_start.push(response_time);
                            
                            // Record orientation response (0-180°)
                            var response_orientation = trial.current_orientation;
                            var response_angle_360 = angleDeg360;
                            degrees.push(response_orientation);
                            radians.push(response_orientation * Math.PI / 180);
                            response_angle_360_saved = response_angle_360;
                            if (typeof trial_data === 'object' && trial_data !== null) {
                                trial_data.response_orientation_360 = response_angle_360_saved;
                            }
                            
                            // Calculate error (difference from target orientation)
                            var target_orientation = trial.orientations[targetN];
                            var target_angle_360_a = target_orientation;
                            var target_angle_360_b = (target_orientation + 180) % 360;
                            var diff_a = ((response_angle_360 - target_angle_360_a + 540) % 360) - 180;
                            var diff_b = ((response_angle_360 - target_angle_360_b + 540) % 360) - 180;
                            var target_angle_360 = Math.abs(diff_a) <= Math.abs(diff_b) ? target_angle_360_a : target_angle_360_b;
                            var angle_diff_360 = Math.abs(diff_a) <= Math.abs(diff_b) ? diff_a : diff_b;
                            var error = Math.abs(angle_diff_360);
                            if (error > 90) {
                                error = 180 - error;
                            }
                            
                            resp_error.push(error);
                            derotated_degrees.push(response_orientation); // For compatibility
                            
                            // Draw feedback with wheel parameters
                            this.drawOrientationBarFeedback(ctx, trial, midx, midy, targetN, indiv_patch_radius, 
                                                           response_orientation, target_orientation, response_angle_360, target_angle_360, wheelOuter, wheelWidth, lineExtension, lineThickness);
                            
                            // Calculate points (100 - error percentage, max 90° = 100% error)
                            points.push(Math.max(0, 100 - Math.round(error / 90 * 100)));
                            
                            finished = true;
                            end_trial();
                        }

                        prev_distance = distance;
                    }.bind(this));

                    function recordOrientationSamples() {
                        orientationSampleCount += 1;
                        if (orientationSampleCount == interval) {
                            orientationSampleCount = 0;
                            var coor = "(" + x_mouse + "," + y_mouse + ")";
                            mouse_coords.push(coor);
                            mouse_coord_rts.push(Math.round(performance.now() - start_time));
                        }
                    }
                    orientationMouseInterval = setInterval(recordOrientationSamples, interval);
                    
                    // Continuous redraw for smooth rotation
                    var animationFrameId;
                    var self = this;
                    function animateOrientationBar() {
                        if (!finished && !endtrial) {
                            ctx.clearRect(0, 0, canvas.width, canvas.height);
                            
                            // Draw center circle for penalty reference
                            const circle = new Path2D();
                            circle.arc(midx, midy, startingradius, 0, 2 * Math.PI);
                            ctx.strokeStyle = 'white';
                            ctx.lineWidth = 1;
                            ctx.stroke(circle);
                            
                            // Redraw orientation bar with wheel
                            self.drawOrientationBarResponse(ctx, trial, midx, midy, targetN, indiv_patch_radius, 
                                                          wheelOuter, wheelWidth, lineExtension, lineThickness);
                            animationFrameId = requestAnimationFrame(animateOrientationBar);
                        }
                    }
                    animateOrientationBar();
                    
                    // Store animation frame ID for cleanup in end_trial
                    trial._orientationBarAnimationId = animationFrameId;
                    trial._orientationMouseInterval = orientationMouseInterval;
                    
                } else {
                    // ============================================================
                    // COLOR WHEEL RESPONSE: Original mouse interaction
                    // ============================================================
                    
                    var hasFirstMoveColor = false;
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
                        if (!hasFirstMoveColor && (x_mouse != 0 || y_mouse != 0)) {
                            hasFirstMoveColor = true;
                            if (distance > startingradius) {
                                startoutofCenter[0] = true;
                            }
                        }
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
                            var response_time = performance.now() - start_time;
                            var movement_rt = leavecenterRT.length ? (response_time - leavecenterRT[0]) : response_time;
                            if (startoutofCenter[0]) {
                                leavecenterRT[0] = null;
                                toofast[0] = false;
                                tooslow[0] = false;
                            } else {
                                if (leavecenterRT.length && leavecenterRT[0] < leaveCenterTooFastMs) {
                                    toofast[0] = true;
                                }
                                if (response_time < responseTooFastMs) {
                                    toofast[0] = true;
                                }
                                if (leavecenterRT.length && leavecenterRT[0] > leaveCenterTooSlowMs) {
                                    tooslow[0] = true;
                                }
                                if (response_time > responseTooSlowMs) {
                                    tooslow[0] = true;
                                }
                            }
                            rt.push(movement_rt);
                            response_rt_from_start.push(response_time);
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

            var targetAngleNoRotation = safeTargetIndex !== null ? safeChoiceAngles[safeTargetIndex] : null;
            var targetAngleRotated = null;
            if (targetAngleNoRotation !== null && typeof trial.wheel_rotation !== 'undefined') {
                var rotationValue = Number(trial.wheel_rotation) || 0;
                var rotated = (targetAngleNoRotation + rotationValue) % 360;
                if (rotated < 0) { rotated += 360; }
                targetAngleRotated = rotated;
            }

            var trial_data = {
                // Task Variables
                num_items: safeChoiceColors.length,
                target_color: safeTargetIndex !== null ? safeChoiceColors[safeTargetIndex] : null,
                target_angle_norotation: targetAngleNoRotation,
                target_angle_rotated: targetAngleRotated,
                rotation: trial.wheel_rotation,
                redundancy: trial.redundancy,

                // Initial Precision Judgement 
                response_radians: radians,
                response_orientation: degrees,

                response_orientation_360: response_angle_360_saved,
                response_error_deg: resp_error,
                response_RT: rt,
                response_RT_from_start: response_rt_from_start,
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
                all_patch_orientations: Array.isArray(trial.orientations) ? trial.orientations : null,
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