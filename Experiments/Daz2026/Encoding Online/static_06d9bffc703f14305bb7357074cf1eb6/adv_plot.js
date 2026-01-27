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
            const setSizePoints = {};
            const setSizeCounts = {};
            const pointSetSizes = Array.isArray(trial.patchN)
                ? trial.patchN.slice(0, trial.points.length)
                : [];
            for (var ii = 0; ii < trial.points.length; ii++) {
                var point = Number(trial.points[ii]);
                if (!Number.isFinite(point) || point <= 0) { point = 1; }
                var setSize = Number(pointSetSizes[ii]);
                if (!Number.isFinite(setSize)) {
                    continue;
                }
                if (!setSizePoints[setSize]) {
                    setSizePoints[setSize] = [];
                }
                setSizePoints[setSize].push(point);
            }
            for (var jj = 0; jj < trial.patchN.length; jj++) {
                var size = Number(trial.patchN[jj]);
                if (!Number.isFinite(size)) {
                    continue;
                }
                setSizeCounts[size] = (setSizeCounts[size] || 0) + 1;
            }
            const sizes = Object.keys(setSizeCounts).map(Number).sort((a, b) => a - b);

            display_element.style.position = 'relative';

            var canvas = document.createElement("canvas");
            canvas.style.margin = "0";
            canvas.style.padding = "0";
            canvas.style.display = "block";
            var ctx = canvas.getContext("2d");
            ctx.canvas.width = window.outerWidth * 0.95;
            ctx.canvas.height = window.outerHeight * 0.95;
            display_element.appendChild(canvas);

            var button = document.createElement('button');
            button.innerHTML = 'Press to continue';
            button.style.position = 'absolute';
            button.style.transform = 'translate(-50%, -50%)';
            display_element.appendChild(button);

            var trialCountText = 'Trial ' + (trial.points.length + 1) + ' of ' + trial.trialN;
            ctx.font = "20px Arial";
            ctx.fillStyle = 'white';
            ctx.textAlign = "center";
            ctx.fillText(trialCountText, ctx.canvas.width / 2, ctx.canvas.height / 2 - 25);

            const baseOffset = canvas.width * 0.05; // Margin for labels
            const plotSpacing = 100; // Space between plots (px)
            const plotCount = Math.max(sizes.length, 1);
            const barWidthPx = 2;
            const barGapPx = 2;
            const leftBarGapPx = 2;
            const axisLineWidth = 2;
            const axisTextGapPx = 5;
            const plotWidths = sizes.map(function (setSize) {
                const xAxisMax = setSizeCounts[setSize] || 0;
                if (!xAxisMax) {
                    return 0;
                }
                return leftBarGapPx + (xAxisMax * (barWidthPx + barGapPx)) - barGapPx;
            });
            const totalGroupWidth = plotWidths.reduce((sum, w) => sum + w, 0) + plotSpacing * (plotCount - 1);
            const groupOffset = (canvas.width - totalGroupWidth) / 2;

            const xAxisIntervals = {
                1: 5,
                2: 15,
                4: 30,
                6: 50
            };
            const preferredXAxisInterval = xAxisIntervals[4] || 30;

            function drawLinePlot(setSizePoints, ctx, totalTrials, plotXOffset, lineColor, setSize, plotWidth) {
                const xAxisMax = setSizeCounts[setSize] || setSizePoints.length || trial.trialN;
                if (!plotWidth || plotWidth <= 0) {
                    return;
                }
                var plotHeight = ctx.canvas.height * 0.3;
                var plotX = groupOffset + plotXOffset;
                var plotY = ctx.canvas.height * 0.6;
                var barWidth = barWidthPx;
                ctx.fillStyle = lineColor;

                setSizePoints.forEach(function (point, index) {
                    var x = plotX + leftBarGapPx + (index * (barWidth + barGapPx));
                    var y = plotY + (1 - point / 100) * plotHeight;
                    var barHeight = (point / 100) * plotHeight;
                    ctx.fillRect(x, y, barWidth, barHeight);
                });

                // Add dynamic axis labeling and other drawing code here as previously outlined
                //const xAxisInterval = Math.ceil(xAxisMax / 10); // Adjust label density
                const xAxisInterval = preferredXAxisInterval;
                ctx.strokeStyle = 'white';
                for (let i = 0; i <= xAxisMax; i += xAxisInterval) {
                    let x = plotX + (i / xAxisMax) * plotWidth;
                    let y = plotY + plotHeight + 20; // Spacing below the plot for labels
                    ctx.fillText(i.toString(), x, y);
                }

                // Draw y-axis values
                const yLabelX = plotX - 5;
                ctx.textAlign = "right";
                ctx.textBaseline = "middle";
                for (let i = 0; i <= 100; i += 100) {
                    let x = yLabelX;
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

                // Draw axis border lines (2px) with 5px separation from text
                ctx.save();
                ctx.strokeStyle = 'white';
                ctx.lineWidth = axisLineWidth;
                // Y axis line (left of y-axis labels)
                ctx.beginPath();
                const yAxisLineX = yLabelX + axisTextGapPx;
                ctx.moveTo(yAxisLineX, plotY);
                ctx.lineTo(yAxisLineX, plotY + plotHeight);
                ctx.stroke();
                // X axis line (above x-axis labels)
                ctx.beginPath();
                const xLabelY = plotY + plotHeight + 20;
                const xLabelFontPx = 16;
                const xAxisLineY = xLabelY - axisTextGapPx - xLabelFontPx;
                ctx.moveTo(plotX, xAxisLineY);
                ctx.lineTo(plotX + plotWidth, xAxisLineY);
                ctx.stroke();
                ctx.restore();

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

            const setSizeData = sizes.map(function (size) {
                const colorMap = {1: 'Aquamarine', 2: 'Chartreuse', 4: 'Gold', 6: 'Aqua'};
                return { setSize: size, points: setSizePoints[size] || [], color: colorMap[size] || 'white' };
            });

            //const plotSpacing = ctx.canvas.width * 0.05; // Add a 2% canvas width as spacing
            //const adjustedPlotWidth = (ctx.canvas.width - plotSpacing * (setSizeData.length - 1)) / setSizeData.length;


            let runningOffset = 0;
            setSizeData.forEach(function (data, index) {
                const plotWidth = plotWidths[index] || 0;
                const plotXOffset = runningOffset;
                drawLinePlot(data.points, ctx, trial.trialN, plotXOffset, data.color, data.setSize, plotWidth);
                runningOffset += plotWidth + plotSpacing;
            });

            const canvasRect = canvas.getBoundingClientRect();
            const containerRect = display_element.getBoundingClientRect();
            button.style.left = (canvasRect.left - containerRect.left + canvasRect.width / 2) + 'px';
            button.style.top = (canvasRect.top - containerRect.top + canvasRect.height / 2) + 'px';

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
