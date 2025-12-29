var jsAdvPlot = (function (jspsych) {
    'use strict';
    const info = {
        name: "AdvanceWithPlot",
        parameters: {
            points: {
                type: jspsych.ParameterType.array,
                pretty_name: "Points"
            },
            trialN: {
                type: jspsych.ParameterType.INT,
                pretty_name: "Total Trials"
            },
            patchN: {
                type: jspsych.ParameterType.array,
                pretty_name: "Setsize List"
            }
        }   
    }

    class AdvPlotPlugin {
        constructor(jsPsych) {
            this.jsPsych = jsPsych;
        }


        trial(display_element, trial) {

            setsize1 = []
            setsize2 = []
            setsize4 = []
            setsize6 = []
            for (var ii = 0; ii < trial.points.length; ii++){
                if (trial.patchN[ii] == 1){setsize1.push(trial.points[ii])}
                if (trial.patchN[ii] == 2){setsize2.push(trial.points[ii])}
                if (trial.patchN[ii] == 4){setsize4.push(trial.points[ii])}
                if (trial.patchN[ii] == 6){setsize6.push(trial.points[ii])}
            }
            

            // Create canvas 95% of screen w/h for drawing (avoids scroll trigger)
            var canvas = document.createElement("canvas");
            canvas.style.margin = "0";
            canvas.style.padding = "0";
            var ctx = canvas.getContext("2d");
            ctx.canvas.width  = window.outerWidth * 0.95;
            ctx.canvas.height = window.outerHeight * 0.95;
            

            // 1. Create a central button with the text 'Press to continue'
            const buttonWidth = 200;
            const buttonHeight = 50;
            const buttonX = (canvas.width - buttonWidth) / 2;
            const buttonY = (canvas.height - buttonHeight) / 2;

            var button = document.createElement('button');
            button.innerHTML = 'Press to continue';
            button.style.position = 'absolute';
            button.style.top = '50%';
            button.style.left = '50%';
            button.style.transform = 'translate(-50%, -50%)';
            button.onclick = end_trial;
            display_element.appendChild(button);

            // 2. Display the text 'Trial X of N' under the button
            var trialCountText = 'Trial ' + (trial.points.length + 1) + ' of ' + trial.trialN;
            ctx.font = "20px Arial";
            ctx.fillStyle = 'white';
            ctx.textAlign = "center";
            ctx.fillText(trialCountText, ctx.canvas.width / 2, ctx.canvas.height / 2 + 50);
            const colors = ['blue', 'red', 'green', 'orange'];
            // 3. Draw a line plot for the points array
            function drawLinePlot(points, ctx, totalTrials, plotXOffset, lineColor, setSize) {
                // Set up the line plot dimensions and styling
                var plotWidth = ctx.canvas.width * 0.8;
                var plotHeight = ctx.canvas.height * 0.3;
                var plotMargin = 50;
                var plotX = plotXOffset + (ctx.canvas.width - plotWidth) / 8;
                var plotY = ctx.canvas.height * 0.6;
                

                // Draw the line plot
                ctx.lineWidth = 2;
                ctx.strokeStyle = lineColor;
                ctx.beginPath();
                points.forEach((point, index) => {
                    var x = plotX + (index / (totalTrials - 1)) * plotWidth;
                    var y = plotY + (1 - point / 100) * plotHeight;
                    if (index === 0) {
                        ctx.moveTo(x, y);
                    } else {
                        ctx.lineTo(x, y);
                    }
                });
                ctx.stroke();

                // Draw red dots for each point
                ctx.fillStyle = 'red';
                points.forEach((point, index) => {
                    var x = plotX + (index / (totalTrials - 1)) * plotWidth;
                    var y = plotY + (1 - point / 100) * plotHeight;
                    ctx.beginPath();
                    ctx.arc(x, y, 3, 0, 2 * Math.PI);
                    ctx.fill();
                });

                ctx.font = "14px Arial";
                ctx.fillStyle = 'white';
                ctx.textAlign = "center";
                ctx.textBaseline = "top";

                // Draw x-axis values
                for (let i = 0; i < totalTrials; i++) {
                    if ((i + 1) % 20 === 0 || i === 0 || i === totalTrials - 1) {
                        let x = plotX + (i / (totalTrials - 1)) * plotWidth;
                        let y = plotY + plotHeight + 5;
                        ctx.fillText((i + 1).toString(), x, y);
                    }
                }

                // Draw y-axis values
                ctx.textAlign = "right";
                ctx.textBaseline = "middle";
                for (let i = 0; i <= 100; i += 20) {
                    let x = plotX - 5;
                    let y = plotY + (1 - i / 100) * plotHeight;
                    ctx.fillText(i.toString(), x, y);
                }

                // Draw y-axis title
                ctx.save();
                ctx.translate(plotX - 40, plotY + plotHeight / 2);
                ctx.rotate(-Math.PI / 2);
                ctx.textAlign = 'center';
                ctx.fillText('Points', 0, 0);
                ctx.restore();

                // Draw x-axis title
                ctx.textAlign = 'center';
                ctx.fillText('Trial', plotX + plotWidth / 2, plotY + plotHeight + 40);
            }

            for (let i = 0; i < trial.points.length; i++) {
                const setSize = trial.patchN[i];
                const setSizePoints = trial.points.filter(function (point) {
                    return point.setSize === setSize;
                }).map(function (point) {
                    return point.value;
                });
                const plotXOffset = (ctx.canvas.width / trial.patchN.length) * i;
                const lineColor = colors[i];
                drawLinePlot(setSizePoints, ctx, trial.trialN, plotXOffset, lineColor, setSize);
            }

            // Add the canvas to the display element
            display_element.appendChild(canvas);

            function end_trial() {
                display_element.innerHTML = ''; // Clear the display element
                this.jsPsych.finishTrial();
            }

            canvas.addEventListener('click', function (event) { 
                const rect = canvas.getBoundingClientRect();
                const x = event.clientX - rect.left;
                const y = event.clientY - rect.top;

                if (x >= buttonX && x <= buttonX + buttonWidth && y >= buttonY && y <= buttonY + buttonHeight) {
                    bound_end_trial()
                } else {
                    
                }
            })

            const bound_end_trial = end_trial.bind(this);
            button.onclick = bound_end_trial;

            
        }
    }
    AdvPlotPlugin.info = info;

    return AdvPlotPlugin;

})(jsPsychModule);
