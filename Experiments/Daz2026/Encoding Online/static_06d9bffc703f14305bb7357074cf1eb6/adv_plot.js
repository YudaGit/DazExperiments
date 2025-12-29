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

            // Assuming these are the total trial counts for each set size
            const totalTrialCounts = {
                1: 15,
                2: 56,
                4: 130,
                6: 204
            };

            for (var ii = 0; ii < trial.points.length; ii++) {
                var point = trial.points[ii];
                if (point == 0) { point = 1; }
                if (trial.patchN[ii] == 1) { setsize1.push(point); }
                if (trial.patchN[ii] == 2) { setsize2.push(point); }
                if (trial.patchN[ii] == 4) { setsize4.push(point); }
                if (trial.patchN[ii] == 6) { setsize6.push(point); }
            }

            var canvas = document.createElement("canvas");
            canvas.style.margin = "0";
            canvas.style.padding = "0";
            var ctx = canvas.getContext("2d");
            ctx.canvas.width = window.outerWidth * 0.95;
            ctx.canvas.height = window.outerHeight * 0.95;

            var button = document.createElement('button');
            button.innerHTML = 'Press to continue';
            button.style.position = 'absolute';
            button.style.top = '50%';
            button.style.left = '50%';
            button.style.transform = 'translate(-50%, -50%)';
            display_element.appendChild(button);

            var trialCountText = 'Trial ' + (trial.points.length + 1) + ' of ' + trial.trialN;
            ctx.font = "20px Arial";
            ctx.fillStyle = 'white';
            ctx.textAlign = "center";
            ctx.fillText(trialCountText, ctx.canvas.width / 2, ctx.canvas.height / 2 - 25);

            const baseOffset = canvas.width * 0.05; // Shift everything to the right by 5% of the canvas width
            const plotSpacing = canvas.width * 0.02; // Space between plots
            const totalPlotWidth = canvas.width - baseOffset * 2; // Total width available for plots
            const adjustedPlotWidth = (totalPlotWidth - plotSpacing * 3) / 4; // Adjust plot width for 4 plots

            const xAxisIntervals = {
                1: 5,
                2: 15,
                4: 30,
                6: 50
            };

            function drawLinePlot(setSizePoints, ctx, totalTrials, plotXOffset, lineColor, setSize) {
                const xAxisMax = totalTrialCounts[setSize];
                var plotWidth = ctx.canvas.width * 0.15;
                var plotHeight = ctx.canvas.height * 0.3;
                var plotX = baseOffset + plotXOffset;
                var plotY = ctx.canvas.height * 0.6;
                var barWidth = plotWidth / xAxisMax;
                ctx.fillStyle = lineColor;

                setSizePoints.forEach(function (point, index) {
                    //var x = plotX + (index * plotWidth / Math.max(setSizePoints.length, 1));
                    var x = plotX + (index * barWidth);
                    var y = plotY + (1 - point / 100) * plotHeight;
                    var barHeight = (point / 100) * plotHeight;
                    ctx.fillRect(x, y, barWidth, barHeight);
                });

                // Add dynamic axis labeling and other drawing code here as previously outlined
                //const xAxisInterval = Math.ceil(xAxisMax / 10); // Adjust label density
                const xAxisInterval = xAxisIntervals[setSize];
                ctx.strokeStyle = 'white';
                for (let i = 0; i <= xAxisMax; i += xAxisInterval) {
                    let x = plotX + (i / xAxisMax) * plotWidth;
                    let y = plotY + plotHeight + 20; // Spacing below the plot for labels
                    ctx.fillText(i.toString(), x, y);
                }

                // Draw y-axis values
                ctx.textAlign = "right";
                ctx.textBaseline = "middle";
                for (let i = 0; i <= 100; i += 100) {
                    let x = plotX - 5;
                    let y = plotY + (1 - i / 100) * plotHeight;
                    ctx.fillText(i.toString() + "%", x, y); // Assuming points are percentages
                }

                // Draw y-axis title
                ctx.save();
                ctx.translate(plotX - 40, plotY + plotHeight * .33);
                ctx.rotate(-Math.PI / 2);
                ctx.fillText('Points', 0, 0);
                ctx.restore();

                // Draw x-axis title
                ctx.textAlign = 'center';
                ctx.fillText('Trial Number', plotX + plotWidth / 2, plotY + plotHeight + 40);

                // Draw plot title
                ctx.font = "16px Arial";
                ctx.fillText('Set Size ' + setSize, plotX + plotWidth / 2, plotY - 30);

                // If there's more than one point, draw a mean line
                if (setSizePoints.length > 1) {
                    var mean = setSizePoints.reduce((a, b) => a + b, 0) / setSizePoints.length;
                    ctx.strokeStyle = 'white';
                    ctx.beginPath();
                    var meanY = plotY + (1 - mean / 100) * plotHeight;
                    ctx.moveTo(plotX, meanY);
                    ctx.lineTo(plotX + plotWidth, meanY);
                    ctx.setLineDash([5, 5]); // Set line dash with a pattern of 5 pixels on, 5 pixels off
                    ctx.stroke();
                    ctx.setLineDash([]);
                }

            }

            const setSizeData = [
                { setSize: 1, points: setsize1, color: 'Aquamarine' },
                { setSize: 2, points: setsize2, color: 'Chartreuse' },
                { setSize: 4, points: setsize4, color: 'Gold' },
                { setSize: 6, points: setsize6, color: 'Aqua' }
            ];

            //const plotSpacing = ctx.canvas.width * 0.05; // Add a 2% canvas width as spacing
            //const adjustedPlotWidth = (ctx.canvas.width - plotSpacing * (setSizeData.length - 1)) / setSizeData.length;


            setSizeData.forEach(function (data, index) {
                const plotXOffset = (adjustedPlotWidth + plotSpacing) * index;
                drawLinePlot(data.points, ctx, trial.trialN, plotXOffset, data.color, data.setSize);
            });

            display_element.appendChild(canvas);

            function end_trial() {
                display_element.innerHTML = '';
                this.jsPsych.finishTrial();
            }

            const bound_end_trial = end_trial.bind(this);
            button.onclick = bound_end_trial;
        }
    }
    AdvPlotPlugin.info = info;

    return AdvPlotPlugin;
})(jsPsychModule);
