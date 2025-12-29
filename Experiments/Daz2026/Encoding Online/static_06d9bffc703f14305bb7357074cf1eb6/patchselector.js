var jsPatchSelector = (function (jspsych) {
    'use strict';

    const info = {
        name: "wheel-image",
        parameters: {
            /** The image to be displayed */
            stimulus: {
                type: jspsych.ParameterType.IMAGE,
                pretty_name: "Stimulus",
                default: '',
            },
            /** Set the image height in pixels */
            stimulus_height: {
                type: jspsych.ParameterType.INT,
                pretty_name: "Image height",
                default: null,
            },
            /** Set the image width in pixels */
            stimulus_width: {
                type: jspsych.ParameterType.INT,
                pretty_name: "Image width",
                default: null,
            },
            /** Maintain the aspect ratio after setting width or height */
            maintain_aspect_ratio: {
                type: jspsych.ParameterType.BOOL,
                pretty_name: "Maintain aspect ratio",
                default: true,
            },
            /** Array containing the color(s) for the button(s). */
            choice_colors: {
                type: jspsych.ParameterType.array,
                pretty_name: "Button Colors",
                default: [],
                array: true,
            },
            choice_angles: {
                type: jspsych.ParameterType.array,
                pretty_name: "Button Color Angles",
                default: [],
                array: true,
            },
            /** Array containing the position(s) of the button(s). */
            choice_positions: {
                type: jspsych.ParameterType.array,
                pretty_name: "Button Positions",
                default: [],
                array: true,
            },
            /** The HTML for creating button. Can create own style. Use the "%choice%" string to indicate where the label from the choices parameter should be inserted. */
            button_html: {
                type: jspsych.ParameterType.HTML_STRING,
                pretty_name: "Button HTML",
                default: '<squarebutton></squarebutton>',
                array: true,
            },
            
            /** How long to show the trial. */
            trial_duration: {
                type: jspsych.ParameterType.INT,
                pretty_name: "Trial duration",
                default: null,
            },
            
            /** If true, then trial will end when user responds. */
            response_ends_trial: {
                type: jspsych.ParameterType.BOOL,
                pretty_name: "Response ends trial",
                default: true,
            },
            draw_wheel: {
                type: jspsych.ParameterType.BOOL,
                pretty_name: "Image height",
                default: true,
            },
            wheel_rotation: {
                type: jspsych.ParameterType.INT,
                pretty_name: "Stimulus Rotation",
                default: 0,
            },
            patch_saturation: {
                type: jspsych.ParameterType.BOOL,
                pretty_name: "Saturation Level",
                default: 1,
            },
        },
    };
    

    class PatchSelectorPlugin {
        constructor(jsPsych) {
            this.jsPsych = jsPsych;
        }
        trial(display_element, trial) {
            var height, width;
            var html;
            var chosen_degrees = [];
            var chosen_color = [];
            var disp_degrees = [];
            var disp_color = [];
            var color_response_rt = [];
            var response_rt = [];
            var adj_trial_angles = [];
            var mouse_response;
            var mouse_coords = [];
            var mouse_coord_rts = [];
                
            var targetN = Math.floor(Math.random() * (trial.choice_colors.length ));

            // first clear the display element (because the render on canvas method appends to display_element instead of overwriting it with .innerHTML)
            if (display_element.hasChildNodes()) {
                while (display_element.firstChild) {
                    display_element.removeChild(display_element.firstChild);
                }
            }
            // create canvas element and image
            var canvas = document.createElement("canvas");
            canvas.id = "canvas-wheel";
            canvas.style.margin = "0";
            canvas.style.padding = "0";
            var ctx = canvas.getContext("2d");
            var img = new Image();
            img.onload = () => {
                // if image wasn't preloaded, then it will need to be drawn whenever it finishes loading
                if (trial.draw_wheel) {
                    getHeightWidth(); // only possible to get width/height after image loads
                    ctx.translate( canvas.width/2, canvas.height/2 )
                    ctx.rotate(trial.wheel_rotation * Math.PI/180)
                    ctx.drawImage(img, -canvas.height/2, -canvas.width/2, canvas.width, canvas.height);
                }
            };
            
            img.src = trial.stimulus;
            // // get/set image height and width - this can only be done after image loads because uses image's naturalWidth/naturalHeight properties
            const getHeightWidth = () => {
                if (trial.stimulus_height !== null) {
                    height = trial.stimulus_height;
                    if (trial.stimulus_width == null && trial.maintain_aspect_ratio) {
                        width = img.naturalWidth * (trial.stimulus_height / img.naturalHeight);
                    }
                }
                else {
                    height = img.naturalHeight;
                }
                if (trial.stimulus_width !== null) {
                    width = trial.stimulus_width;
                    if (trial.stimulus_height == null && trial.maintain_aspect_ratio) {
                        height = img.naturalHeight * (trial.stimulus_width / img.naturalWidth);
                    }
                }
                else if (!(trial.stimulus_height !== null && trial.maintain_aspect_ratio)) {
                    // if stimulus width is null, only use the image's natural width if the width value wasn't set
                    // in the if statement above, based on a specified height and maintain_aspect_ratio = true
                    width = img.naturalWidth;
                }
                canvas.height = height;
                canvas.width = width;
            };
            getHeightWidth(); // call now, in case image loads immediately (is cached)

            // create colored buttons
            var buttons = [];
            if (Array.isArray(trial.button_html)) {
                if (trial.button_html.length == trial.choice_colors.length) {
                    buttons = trial.button_html;
                }
            }
            else {
                for (var i = 0; i < trial.choice_colors.length; i++) {
                    buttons.push(trial.button_html);
                }
            }

            buttons.push(trial.button_html)

            canvas.addEventListener( "mousemove", function(e){
                  var x_mouse = e.offsetX - canvas.height/2;
                  var y_mouse = canvas.height/2 - e.offsetY;
                  var coor = "(" + x_mouse + "," + y_mouse + ")";
                  if( performance.now() - mouse_timer > 100 ){
                    mouse_timer = performance.now();
                    mouse_coords.push(coor);
                    mouse_coord_rts.push( Math.round( performance.now() - start_time ) );
                  }
              });    
            
            var btngroup_div = document.createElement("div");
            btngroup_div.id = "jspsych-image-button-response-btngroup";

            html = "";
            for (var i = 0; i < trial.choice_colors.length; i++) {                
                var str = buttons[i];
                if (trial.draw_wheel){

                    if (i == targetN){
                        html +=
                        '<div class="wheel-button" ' + 
                        'style="position: absolute; padding: 17px 17px; ' +
                        'top: '   + trial.choice_positions[i][1] + 'px; ' + 
                        'right: ' + trial.choice_positions[i][0] + 'px; ' + 
                        //choice_positions
                        ' border-width: thick; border: solid rgb(0, 0, 0); background-color: rgb( 128, 128, 128 ); ' + 
                            '" id="wheel-button-' +
                            i +
                            '" data-choice="' +
                            i +     
                            '" clicked="' +
                            0 +
                            '">' +
                            str +
                            "</div>";
                    } else {
                        html +=
                        '<div class="wheel-button" ' + 
                        'style="position: absolute; padding: 17px 17px; ' +
                        'top: '   + trial.choice_positions[i][1] + 'px; ' + 
                        'right: ' + trial.choice_positions[i][0] + 'px; ' + 
                        //choice_positions
                        ' border: ridge rgb(135, 135, 135); background-color: rgb( 128, 128, 128 ); ' + 
                            '" id="wheel-button-' +
                            i +
                            '" data-choice="' +
                            i +     
                            '" clicked="' +
                            0 +
                            '">' +
                            str +
                            "</div>";
                    }
                } else {
                html +=
                    '<div class="wheel-button" ' + 
                    'style="position: absolute; padding: 17px 17px; ' +
                    'top: '   + trial.choice_positions[i][1] + 'px; ' + 
                    'right: ' + trial.choice_positions[i][0] + 'px; ' + 
                    //choice_positions
                    ' border: none; background-color: rgb(' + 
                        trial.choice_colors[i][0] + 
                        ', ' + trial.choice_colors[i][1] +  
                        ', ' + trial.choice_colors[i][2] +  '); ' + 
                        '" id="wheel-button-' +
                        i +
                        '" data-choice="' +
                        i +     
                        '" clicked="' +
                        0 +
                        '">' +
                        str +
                        "</div>";
                }
            }

            btngroup_div.innerHTML = html;
            // // add canvas to screen and draw image
            display_element.insertBefore(canvas, null);
            // // add buttons to screen
            display_element.insertBefore(btngroup_div, canvas.nextElementSibling);

            // // start timing
            var start_time = performance.now();
            var mouse_timer = performance.now();
            // var button_responses;
            

            // end trial if time limit is set
            if (trial.trial_duration !== null) {
                this.jsPsych.pluginAPI.setTimeout(() => {
                    end_trial();
                }, trial.trial_duration);
            }

            const end_trial = () => {
                // kill any remaining setTimeout handlers
                this.jsPsych.pluginAPI.clearAllTimeouts();
                // clear the display
                display_element.innerHTML = "";
                // context.drawImage(tempCanvas, 0, 0);
                if (trial.draw_wheel){
                    ctx.translate( -canvas.width/2, -canvas.height/2 )
                    ctx.rotate(-trial.wheel_rotation * Math.PI/180)
                    ctx.clearRect(0, 0, ctx.canvas.width, ctx.canvas.height)
                    // end current trial
                    this.jsPsych.finishTrial(trial_data);
                } else {
                    // move on response selection
                    this.jsPsych.finishTrial(PatchDisplay_data);
                }                
            };

            var PatchDisplay_data = { 
                positionFromRightAndTop: trial.choice_positions,
                disp_color: disp_color
            }

            var trial_data = {
                stimulus: trial.stimulus,
                saturation: trial.patch_saturation,
                saturationString: ['Low', 'High'][trial.patch_saturation],
                positionFromScreenRightAndTop: trial.choice_positions,
                rotation: trial.wheel_rotation,
                response_order: targetN + 1, 
                mouse_response: mouse_response,
                patch_initiate_rt: response_rt,
                color_response_rt: color_response_rt,
                intial_chosen_degrees: disp_degrees,
                adjusted_chosen_degrees: chosen_degrees,
                chosen_color: chosen_color,
                initial_disp_degrees: trial.choice_angles,
                adjusted_disp_degrees: adj_trial_angles,
                disp_color: disp_color, 
                mouse_coords: mouse_coords,
                mouse_coord_rts: mouse_coord_rts,
                wheel_canvas_height_width: [canvas.height, canvas.width],
                all_colors: trial.choice_colors,
                num_items: trial.choice_colors.length
            };
            var button_active = 0

            // Loop for handling button presses...           
            if (trial.draw_wheel){
                var clicked = []
                for (var i = 0; i < trial.choice_colors.length; i++) {
                    clicked[i] = display_element.querySelector("#wheel-button-" + i).getAttribute("clicked")
                    
                    display_element
                        .querySelector("#wheel-button-" + i)
                        .addEventListener("click", (e) => {
                        var btn_el = e.currentTarget;
                        var choice = btn_el.getAttribute("data-choice"); // don't use dataset for jsdom compatibility

                        if (clicked[choice] == 0 && button_active == 0){
                            clicked[choice] = 1
                            patch_click(choice)
                        } 
                    });
                }
            }

            function adjust_degrees(degrees, rotation){

                var adjdeg = degrees - rotation
                if (adjdeg < 0){
                    adjdeg = Math.abs( 359.999 + adjdeg )
                }
                return(adjdeg)
            }

            function readjust_degrees(degrees, rotation){

                var readjdeg = degrees + rotation
                if (readjdeg >= 359.999){
                    readjdeg = Math.abs( readjdeg - 359.999 )
                }
                return(readjdeg)
            }
            
            function logMouseButton(e) {
                if (typeof e === 'object') {
                  switch (e.button) {
                    case 0:
                        mouse_response = 'left mouse'
                      break;
                    case 1:
                        mouse_response = 'middle mouse'
                      break;
                    case 2:
                        mouse_response = 'right mouse'
                      break;
                    default:
                        mouse_response = 'unknown mouse'
                    }
                }
            }

            function patch_click(choice){
                if (choice == targetN){
                    button_active = 1
                    
                    display_element.querySelector("#wheel-button-" + choice).style.border = 'solid rgb(150, 150, 150)'
                    var end_time = performance.now();
                    var rt = Math.round(end_time - start_time);
                    response_rt.push(rt)
                    // button_responses = choice
                    var fix_color = false
                    var return_mouse = true

                    canvas.addEventListener('mousemove', e => {

                        var x = e.offsetX - canvas.height/2;
                        var y = canvas.height/2 - e.offsetY;
        
                        var rad = 2 * Math.atan( y / ( x + Math.sqrt( x * x + y * y ) ) )
                        var degrees = rad * (180/ Math.PI)
        
                        if (degrees > 0){
                            degrees = Math.abs(degrees - 180) + 180
                        }
                        if (degrees < 0){
                            degrees = Math.abs(degrees)
                        }
                        
                        //.log(degrees, trial.wheel_rotation)
                        var initial_degrees = degrees
                        degrees = adjust_degrees(degrees, trial.wheel_rotation)
                        
                        var color = highRGBs[Math.floor(degrees)]
                        
                        
                        var btn_choice = display_element.querySelector("#wheel-button-" + choice)
                        
                        if (!fix_color && Math.sqrt(x * x + y * y) > (canvas.height * .36) ){
                            btn_choice.style.backgroundColor = 'rgb(' + color[0] + ', ' + color[1] +  ', ' + color[2] +  ')' 
                            canvas.addEventListener('mousedown', logMouseButton);
                            canvas.addEventListener('mousedown', function(event){
                                fix_color = true

                                if (return_mouse){
                                    return_mouse = false
                                    canvas.removeEventListener('mousedown', logMouseButton);
                                    
                                    var color_time = performance.now();
                                    chosen_degrees.push(degrees)
                                    chosen_color.push(color)
                                    disp_degrees.push(initial_degrees)

                                    adj_trial_angles.push(adjust_degrees(trial.choice_angles[chosen_degrees.length-1], trial.wheel_rotation) )
                                    disp_color.push(trial.choice_colors[choice])
                                    color_response_rt.push(Math.round( color_time - start_time ) )
                                    button_active = 0
                                    display_element.querySelector("#wheel-button-" + choice).style.border = 'none'

                                    
                                    end_trial()
                                        
                                }
                            })
                        }
                    })
                } else {
                    return
                }
            }
        }
    }
    PatchSelectorPlugin.info = info;
  
    return PatchSelectorPlugin;
  
  })(jsPsychModule);