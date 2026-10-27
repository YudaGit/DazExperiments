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
            var setsize1 = [];
            var setsize2 = [];
            var setsize4 = [];
            var setsize6 = [];


            for (var ii = 0; ii < trial.points.length; ii++) {
                var point = trial.points[ii]
                if (point == 0){point = 1}
                if (trial.patchN[ii] == 1) { setsize1.push(point); }
                if (trial.patchN[ii] == 2) { setsize2.push(point); }
                if (trial.patchN[ii] == 4) { setsize4.push(point); }
                if (trial.patchN[ii] == 6) { setsize6.push(point); }
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
            ctx.fillText(trialCountText, ctx.canvas.width / 2, ctx.canvas.height / 2 - 25);

            // 3. Draw a line plot for each set size
            function drawLinePlot(setSizePoints, ctx, totalTrials, plotXOffset, lineColor, setSize) {
                // Set up the line plot dimensions and styling
                var plotWidth = ctx.canvas.width * 0.15;
                var plotHeight = ctx.canvas.height * 0.3;
                var plotMargin = 50;
                var plotX = plotXOffset + (ctx.canvas.width - plotWidth) / 12;
                var plotY = ctx.canvas.height * 0.6;
                const xAxisMax = 90;
                const xAxisStep = 15;
                var sum = setSizePoints.reduce(function (a, b) { return a + b; }, 0);
                var mean = sum / setSizePoints.length;
                var barWidth = plotWidth / xAxisMax;
                ctx.fillStyle = lineColor;
                setSizePoints.forEach(function(point, index) {
                var x = plotX + index * barWidth;
                var y = plotY + (1 - point / 100) * plotHeight;
                var barHeight = (point / 100) * plotHeight;
                ctx.fillRect(x, y, barWidth, barHeight);
                });

                ctx.font = "14px Arial";
                ctx.fillStyle = 'white';
                ctx.textAlign = "center";
                ctx.textBaseline = "top";

                // Draw x-axis values
                for (let i = 0; i <= xAxisMax; i += xAxisStep) {
                    let x = plotX + (i / xAxisMax) * plotWidth;
                    let y = plotY + plotHeight + 5;
                    ctx.fillText(i.toString(), x, y);
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

                // Draw plot title
                ctx.font = "15px Arial";
                ctx.fillStyle = 'white';
                ctx.textAlign = "center";
                ctx.fillText('Set Size ' + setSize, plotX + plotWidth / 2, plotY - 30);

                if (setSizePoints.length > 1){
                    ctx.strokeStyle = 'white';
                    ctx.setLineDash([5, 5])
                    ctx.beginPath();
                    var meanLineStartX = plotX;
                    var meanLineStartY = plotY + (1 - mean / 100) * plotHeight;
                    var meanLineEndX = plotX + plotWidth;
                    var meanLineEndY = meanLineStartY;
                    ctx.moveTo(meanLineStartX, meanLineStartY);
                    ctx.lineTo(meanLineEndX, meanLineEndY);
                    ctx.setLineDash([5, 5]); // Set line dash with a pattern of 5 pixels on, 5 pixels off
                    ctx.stroke();
                    ctx.setLineDash([]);
                }
                
            }

            const setSizeData = [
                { setSize: 1, points: setsize1, color: 'blue' },
                { setSize: 2, points: setsize2, color: 'green' },
                { setSize: 4, points: setsize4, color: 'orange' },
                { setSize: 6, points: setsize6, color: 'red' }
            ];

            setSizeData.forEach(function (data, index) {
                const plotXOffset = (ctx.canvas.width / setSizeData.length) * index;
                drawLinePlot(data.points, ctx, trial.trialN, plotXOffset, data.color, data.setSize);
            });

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
