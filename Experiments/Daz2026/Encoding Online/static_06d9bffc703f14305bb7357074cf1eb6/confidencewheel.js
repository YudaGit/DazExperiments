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
            }
        }   
    }

    class ConfidenceWheelPlugin {
        constructor(jsPsych) {
            this.jsPsych = jsPsych;
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

        trial(display_element, trial) {
            // Set Base Variables
            var maxtime = 10000
            var startingradius = Math.round(window.outerHeight * 0.035);
            var patchradius    = browser_window_height*.1;
            var targetN;
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
            
            //  Add centeral white circle for mouse centering
            var midx = ctx.canvas.width/2
            var midy = ctx.canvas.height/2
            const circle = new Path2D();
            circle.arc(midx, midy, startingradius, 0, 2 * Math.PI);
            ctx.strokeStyle = 'white';
            ctx.border = 'thick';
            ctx.stroke(circle);
            display_element.insertBefore(canvas, null);
            
            var indiv_patch_radius = Math.round(window.outerHeight * 0.024)
            //console.log('p', indiv_patch_radius)
            
            if (trial.draw_wheel == false){
                // Set timeout when showing stimuli
                this.jsPsych.pluginAPI.setTimeout(() => {
                    end_trial();
                }, trial.trial_duration);
                
                // Check stimulus type
                if (trial.stimulus_type === 'orientation_bars' && trial.orientations) {
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
                var outer_radius = Math.round( window.outerHeight * 0.354 )
                var inner_radius = Math.round(outer_radius - window.outerHeight * 0.028)

                
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
            

            if (trial.draw_wheel == true & endtrial == false){

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
              }

            const end_trial = () => {
                // Check for start out of center
                for (ii = 0; ii < pastYcoords.length; ii++){
                    if (pastYcoords[ii] != 0 || pastXcoords[ii] != 0){
                        break
                    }
                }
                if (Math.sqrt( pastYcoords[ii] * pastYcoords[ii] + pastXcoords[ii] * pastXcoords[ii] ) > startingradius ){
                    startoutofCenter[0] = true;
                }

                // ctx.clearRect(0, 0, canvas.width, canvas.height);
                clearInterval(mousecheckinterval)
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
                    
                    if (startoutofCenter[0]){txt = 'Response Started Out Of Center.'}
                    if (toofast[0]){txt = 'Too Fast Leaving The Center.'}
                    if (tooslow[0]){txt = 'Too Slow Leaving The Center.'}
                        
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
                
                    setTimeout(() => { 
                        // console.log('trial data triggered')
                        ctx.clearRect(0, 0, canvas.width, canvas.height);
                        ctx.canvas.remove()
                        this.jsPsych.pluginAPI.clearAllTimeouts();
                        this.jsPsych.finishTrial(trial_data);
                    }, wait_time);

                } else { 
                    // document.getElementById("jspsych-button-group").remove()
                    ctx.clearRect(0, 0, canvas.width, canvas.height);
                    ctx.canvas.remove()
                    this.jsPsych.finishTrial(trial_data);
                }
                
            };
            

            var trial_data = {
                // Task Variables
                num_items: trial.choice_colors.length,
                target_color: trial.choice_colors[targetN],
                target_angle_norotation: trial.choice_colorangles[targetN],
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

                target_patchN: targetN + 1, 
                all_patch_angles: trial.choice_colorangles,
                all_patch_colors: trial.choice_colors,
                patch_angles_from_center: trial.patch_positionalangle,
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