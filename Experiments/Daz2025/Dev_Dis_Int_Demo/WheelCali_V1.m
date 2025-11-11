function WheelCali_V1
% WheelCali_V1.m
%
% Psychtoolbox experiment to estimate individualized hue discriminability
% across 30 hubs using a 3-alternative oddity task with QUEST+ staircases.
%
% The script manages stimulus presentation, QUEST+ updates, data logging,
% post-processing (threshold smoothing, perceptual warp construction), and
% result plots. Helper functions are defined at the end of this file.
%
% Requirements:
%   - MATLAB R2024b or later
%   - Psychtoolbox-3
%   - Access to the existing display calibration pipeline (initiate.m, etc.)
%
% NOTE: Ensure the working directory is this script's folder so that the
% calibration assets (e.g., screenCalibration.mat) can be located.
%
% Author: GPT-5 Codex (2025-11-11)

    clear; clc;

    % Seed RNG for reproducibility and store the seed with each trial.
    rng('shuffle');
    masterSeed = rng;

    % --- Constants -------------------------------------------------------
    params.H             = 30;
    params.theta_h       = 0:12:348;
    params.delta_min     = 1;
    params.delta_max     = 24;
    params.k             = 1.75;
    params.gamma         = 1/3;
    params.lambda        = 0.02;
    params.beta          = 2.5;
    params.presentation_s = 0.500;
    params.mask_s        = 0.500;
    params.hub_trial_target = 24;
    params.hub_trial_max = 30;
    params.posterior_sd_stop = 1.0; % in degrees
    params.sigma_grid = logspace(log10(1), log10(30), 80);
    params.delta_candidates = params.delta_min:params.delta_max;
    params.theta_grid_dense = 0:0.1:360; % for smoothing/warp
    params.figure_base_name = 'WheelCali_V1';

    % --- Setup Psychtoolbox / Display -----------------------------------
    try
        AssertOpenGL;
    catch ME
        error('Psychtoolbox (OpenGL) is required: %s', ME.message);
    end

    KbName('UnifyKeyNames');
    PsychDefaultSetup(2); % Sets standard settings and color range 0..1

    HideCursor;

    % Initialize existing experiment infrastructure if available.
    if exist('initiate', 'file')
        V = initiate();
        win = V.window;
        cleanupFcn = @() cleanup_after_trial(win);
        if ~isfield(V, 'color') || ~isfield(V.color, 'map') || isempty(V.color.map)
            error(['initiate() must populate V.color.map (Nx3 RGB isoluminant wheel). ' ...
                   'Ensure your calibration pipeline is available.']);
        end
        colorWheel = V.color.map;
        if size(colorWheel,1) ~= 360
            idx = round(linspace(1, size(colorWheel,1), 360));
            colorWheel = colorWheel(idx,:);
        end
        if isfield(V, 'layout') && isfield(V.layout, 'centerRadiusPx')
            patchRadiusPx = V.layout.centerRadiusPx;
        else
            patchRadiusPx = estimatePatchRadius(V);
        end
        bgColor = getfield_with_default(V, {'color','bg'}, [0.5 0.5 0.5]);
        maskColor = getfield_with_default(V, {'color','mask'}, [0.5 0.5 0.5]);
    else
        warning('initiate.m not found; using basic Psychtoolbox window.');
        Screen('Preference','SkipSyncTests',1);
        [win, winRect] = PsychImaging('OpenWindow', max(Screen('Screens')), 0.5);
        V = struct();
        V.window = win;
        V.rect = winRect;
        colorWheel = default_oklab_wheel();
        patchRadiusPx = round(min(winRect(3:4))*0.05); % ~1 deg fallback
        bgColor = [0.5 0.5 0.5];
        maskColor = 0.5*ones(1,3);
        cleanupFcn = @() cleanup_after_trial(win);
    end

    display_params.window     = win;
    display_params.bgColor    = bgColor;
    display_params.maskColor  = maskColor;
    display_params.patchRadiusPx = patchRadiusPx;
    display_params.vertices   = equilateral_vertices(win, patchRadiusPx*5);
    display_params.polygonColor = colorWheel;
    display_params.color_fn   = @(theta) theta_to_rgb(theta, colorWheel);
    display_params.response_mode = 'keyboard'; % 'keyboard' or 'mouse'
    display_params.valid_keys = [KbName('1!'), KbName('2@'), KbName('3#')];
    display_params.escape_key = KbName('ESCAPE');
    display_params.help_key   = KbName('H');
    display_params.fixation_color = [0.25 0.25 0.25];
    display_params.fixation_radiusPx = round(patchRadiusPx * 0.2);
    display_params.mask_texture = [];
    display_params.screen_ifis = Screen('GetFlipInterval', win);

    % --- Initialize QUEST states ----------------------------------------
    questStates = init_quest_states(params);

    % Preallocate TrialData container (max H * hub_trial_max).
    maxTrials = params.H * params.hub_trial_max;
    TrialData(maxTrials,1) = struct( ...
        'hub_idx', [], ...
        'theta_h', [], ...
        'delta', [], ...
        'k', params.k, ...
        'sideC', [], ...
        'theta_A', [], ...
        'theta_B', [], ...
        'theta_C', [], ...
        'choice', [], ...
        'is_correct', [], ...
        'rt_ms', [], ...
        'seed', [], ...
        'assignment', [], ...
        'timestamp', []);
    trialCounter = 0;

    % Provide onscreen intro / instructions
    show_instructions(display_params);

    % --- Main experiment loop -------------------------------------------
    try
        allStopped = false;
        hubTrials = zeros(params.H,1);

        while ~allStopped
            hub_order = randperm(params.H);
            for hh = hub_order
                if questStates(hh).stopped
                    continue;
                end

                % Check for trial cap per hub.
                if hubTrials(hh) >= params.hub_trial_max
                    questStates(hh).stopped = true;
                    continue;
                end

                thetaHub = params.theta_h(hh);
                nextDelta = questStates(hh).next_delta;
                if isempty(nextDelta)
                    nextDelta = questplus_suggest_delta(questStates(hh), params);
                    questStates(hh).next_delta = nextDelta;
                end

                trialParams = gen_trial_params(hh, thetaHub, nextDelta, params.k);

                [choice, rt_ms, abortRequested] = render_trial(trialParams, params, display_params);
                if abortRequested
                    error('Experiment aborted by user.');
                end

                is_correct = (choice == trialParams.odd_index);

                % Log trial
                trialCounter = trialCounter + 1;
                TrialData(trialCounter) = struct( ...
                    'hub_idx', hh, ...
                    'theta_h', thetaHub, ...
                    'delta', nextDelta, ...
                    'k', params.k, ...
                    'sideC', trialParams.sideC, ...
                    'theta_A', trialParams.theta_A, ...
                    'theta_B', trialParams.theta_B, ...
                    'theta_C', trialParams.theta_C, ...
                    'choice', choice, ...
                    'is_correct', is_correct, ...
                    'rt_ms', rt_ms, ...
                    'seed', masterSeed.Seed, ...
                    'assignment', trialParams.assignment, ...
                    'timestamp', now);

                hubTrials(hh) = hubTrials(hh) + 1;

                % QUEST+ update (provides next delta)
                [questStates(hh), nextDelta] = questplus_update(questStates(hh), params, is_correct, trialParams.delta);
                questStates(hh).next_delta = nextDelta;

                % Stopping rule
                if questStates(hh).sigma_se < params.posterior_sd_stop ...
                        || hubTrials(hh) >= params.hub_trial_target
                    questStates(hh).stopped = true;
                end

                % Allow quick break if all hubs done
                if all([questStates.stopped])
                    allStopped = true;
                    break;
                end
            end
        end

        % Trim unused trial logs
        TrialData = TrialData(1:trialCounter);

        % --- Post processing --------------------------------------------
        sigma_hat = fit_thresholds(questStates);

        [sigma_spline_fn, sigma_dense, s_dense] = smooth_sigma_to_s(params.theta_h, sigma_hat, params.theta_grid_dense);

        [warpResult, LUT_forward, LUT_inverse] = build_warp_from_s(params.theta_grid_dense, s_dense);

        % --- Plots ------------------------------------------------------
        plot_thresholds(params.theta_h, sigma_hat, params.figure_base_name);
        plot_smoothed_sigma(params.theta_grid_dense, sigma_dense, params.figure_base_name);
        plot_s_function(params.theta_grid_dense, s_dense, params.figure_base_name);
        plot_warp(params.theta_grid_dense, warpResult.forward, params.figure_base_name);

        % --- Save output ------------------------------------------------
        outputFile = fullfile(pwd, 'calibration_output.mat');
        save(outputFile, 'TrialData', 'sigma_hat', 'sigma_spline_fn', ...
            'params', 'questStates', 'LUT_forward', 'LUT_inverse', 'warpResult');

        fprintf('Calibration complete. Data saved to %s\n', outputFile);

    catch ME
        cleanupFcn();
        ShowCursor;
        rethrow(ME);
    end

    cleanupFcn();
    ShowCursor;
end

% -------------------------------------------------------------------------
function questStates = init_quest_states(params)
    numHubs = params.H;
    prior_prob = ones(size(params.sigma_grid));
    prior_prob = prior_prob / sum(prior_prob);

    questTemplate = struct( ...
        'posterior_grid', params.sigma_grid(:)', ...
        'posterior_prob', prior_prob, ...
        'prior_grid', params.sigma_grid(:)', ...
        'prior_prob', prior_prob, ...
        'delta_set', params.delta_candidates(:)', ...
        'stopped', false, ...
        'sigma_est', mean(params.sigma_grid), ...
        'sigma_se', std(params.sigma_grid), ...
        'next_delta', [], ...
        'trial_count', 0);

    questStates = repmat(questTemplate, numHubs, 1);

    for hh = 1:numHubs
        questStates(hh).next_delta = questplus_suggest_delta(questStates(hh), params);
    end
end

% -------------------------------------------------------------------------
function nextDelta = questplus_suggest_delta(qstate, params)
    % Greedy entropy minimization across the candidate deltas.
    grid = qstate.posterior_grid;
    posterior = qstate.posterior_prob;
    delta_set = qstate.delta_set;

    if all(isnan(posterior))
        posterior = qstate.prior_prob;
    end

    currentEntropy = -sum(posterior .* log2(posterior + eps));
    bestGain = -inf;
    bestDelta = delta_set(1);

    for dd = delta_set(:)'
        p_correct = p_correct_oddity(dd, grid, params.beta, params.gamma, params.lambda);
        p_incorrect = 1 - p_correct;

        post_correct = posterior .* p_correct;
        sum_correct = sum(post_correct);
        if sum_correct > 0
            post_correct = post_correct / sum_correct;
            entropy_correct = -sum(post_correct .* log2(post_correct + eps));
        else
            entropy_correct = currentEntropy;
        end

        post_incorrect = posterior .* p_incorrect;
        sum_incorrect = sum(post_incorrect);
        if sum_incorrect > 0
            post_incorrect = post_incorrect / sum_incorrect;
            entropy_incorrect = -sum(post_incorrect .* log2(post_incorrect + eps));
        else
            entropy_incorrect = currentEntropy;
        end

        pc_mean = sum(posterior .* p_correct);
        pi_mean = 1 - pc_mean;

        expectedEntropy = pc_mean * entropy_correct + pi_mean * entropy_incorrect;
        infoGain = currentEntropy - expectedEntropy;
        if infoGain > bestGain
            bestGain = infoGain;
            bestDelta = dd;
        end
    end

    nextDelta = bestDelta;
end

% -------------------------------------------------------------------------
function trialParams = gen_trial_params(hub_idx, thetaHub, delta, k)
    sideC = randsample([-1, 1], 1);
    theta_A = theta_wrap(thetaHub - delta/2);
    theta_B = theta_wrap(thetaHub + delta/2);
    theta_C = theta_wrap(thetaHub + sideC * k * delta);

    assignment = randperm(3);
    odd_index = assignment(3);

    trialParams = struct( ...
        'hub_idx', hub_idx, ...
        'theta_h', thetaHub, ...
        'delta', delta, ...
        'sideC', sideC, ...
        'theta_A', theta_A, ...
        'theta_B', theta_B, ...
        'theta_C', theta_C, ...
        'assignment', assignment, ...
        'odd_index', odd_index);
end

% -------------------------------------------------------------------------
function [choice, rt_ms, abortRequested] = render_trial(trialParams, params, display_params)
    win = display_params.window;
    Screen('FillRect', win, display_params.bgColor);

    vertices = display_params.vertices;
    assignment = trialParams.assignment;

    hues = [trialParams.theta_A, trialParams.theta_B, trialParams.theta_C];
    colors = display_params.color_fn(hues);

    patchRects = compute_patch_rects(vertices, display_params.patchRadiusPx);

    % Draw fixation
    draw_fixation(win, display_params);
    vbl = Screen('Flip', win);

    % Draw stimuli
    for idx = 1:3
        vertexIdx = assignment(idx);
        color = colors(idx, :);
        Screen('FillOval', win, color', patchRects(:, vertexIdx));
    end
    draw_fixation(win, display_params);
    stimOnset = Screen('Flip', win, vbl + 0.5 * display_params.screen_ifis);

    % Stimulus duration
    WaitSecs(params.presentation_s);

    % Mask
    if isempty(display_params.mask_texture)
        Screen('FillRect', win, display_params.maskColor);
    else
        Screen('DrawTexture', win, display_params.mask_texture);
    end
    draw_fixation(win, display_params);
    maskOnset = Screen('Flip', win);

    WaitSecs(params.mask_s);

    % Return to blank fixation for response period
    Screen('FillRect', win, display_params.bgColor);
    draw_fixation(win, display_params);
    Screen('Flip', win);

    abortRequested = false;
    choice = NaN;
    rt_ms = NaN;

    responseStart = GetSecs;

    while isnan(choice)
        [keyIsDown, ~, keyCode] = KbCheck;
        if keyIsDown
            if keyCode(display_params.escape_key)
                abortRequested = true;
                break;
            end
            if any(keyCode(display_params.valid_keys))
                keyIdx = find(keyCode(display_params.valid_keys), 1);
                choice = keyIdx;
                rt_ms = (GetSecs - stimOnset) * 1000;
            end
        end
    end

    if isnan(choice)
        choice = 0;
        rt_ms = (GetSecs - responseStart) * 1000;
    end
end

% -------------------------------------------------------------------------
function [qstate, nextDelta] = questplus_update(qstate, params, is_correct, deltaUsed)
    grid = qstate.posterior_grid;
    posterior = qstate.posterior_prob;

    pc = p_correct_oddity(deltaUsed, grid, params.beta, params.gamma, params.lambda);
    likelihood = pc;
    if ~is_correct
        likelihood = 1 - pc;
    end

    posterior = posterior .* likelihood;
    total = sum(posterior);
    if total <= 0
        posterior = qstate.prior_prob;
    else
        posterior = posterior / total;
    end

    qstate.posterior_prob = posterior;
    qstate.trial_count = qstate.trial_count + 1;

    meanSigma = sum(posterior .* grid);
    sigmaSE = sqrt(sum(posterior .* (grid - meanSigma).^2));

    qstate.sigma_est = meanSigma;
    qstate.sigma_se = sigmaSE;

    nextDelta = questplus_suggest_delta(qstate, params);
end

% -------------------------------------------------------------------------
function sigma_hat = fit_thresholds(questStates)
    numHubs = numel(questStates);
    sigma_hat = zeros(numHubs,1);
    for hh = 1:numHubs
        q = questStates(hh);
        if isempty(q.posterior_prob)
            sigma_hat(hh) = NaN;
        else
            sigma_hat(hh) = sum(q.posterior_prob .* q.posterior_grid);
        end
    end
end

% -------------------------------------------------------------------------
function [sigma_spline_fn, sigma_dense, s_dense] = smooth_sigma_to_s(theta_h, sigma_hat, theta_dense)
    sigma_hat = max(sigma_hat(:), 0.1);
    logSigma = log(sigma_hat(:));
    theta_h = theta_h(:);

    % enforce periodicity by augmenting endpoints
    theta_aug = [theta_h - 360; theta_h; theta_h + 360];
    logSigma_aug = [logSigma; logSigma; logSigma];

    p = 0.8;
    splineFit = csaps(theta_aug, logSigma_aug, p);
    logSigma_dense = fnval(splineFit, theta_dense);
    sigma_dense = exp(logSigma_dense);
    s_dense = 1 ./ sigma_dense;

    sigma_spline_fn = splineFit;
end

% -------------------------------------------------------------------------
function [warpResult, LUT_forward, LUT_inverse] = build_warp_from_s(theta_dense, s_dense)
    theta_dense = theta_dense(:);
    s_dense = s_dense(:);

    cumIntegral = cumtrapz(theta_dense, s_dense);
    totalIntegral = cumIntegral(end) - cumIntegral(1);
    forward = 360 * (cumIntegral - cumIntegral(1)) / totalIntegral;

    % Ensure monotonic via pchip
    forwardInterp = pchip(theta_dense, forward);

    theta_samples = theta_dense;
    phi_samples = fnval(forwardInterp, theta_samples);

    LUT_forward = [theta_samples, phi_samples];

    % Build inverse LUT
    phi_dense = linspace(0, 360, numel(theta_dense))';
    inverseInterp = pchip(phi_samples, theta_samples);
    theta_from_phi = fnval(inverseInterp, phi_dense);
    LUT_inverse = [phi_dense, theta_from_phi];

    warpResult = struct('forward', phi_samples, 'inverse', theta_from_phi, ...
        'theta_dense', theta_dense, 'phi_dense', phi_dense);
end

% -------------------------------------------------------------------------
function p = p_correct_oddity(delta, sigma, beta, gamma, lambda)
    % Logistic psychometric with fixed gamma/lambda.
    z = (delta ./ sigma) .^ beta;
    F = 1 ./ (1 + exp(-z));
    p = gamma + (1 - gamma - lambda) .* F;
end

% -------------------------------------------------------------------------
function theta_w = theta_wrap(theta)
    theta_w = mod(theta, 360);
    theta_w(theta_w < 0) = theta_w(theta_w < 0) + 360;
end

% -------------------------------------------------------------------------
function rgb = theta_to_rgb(theta, colorWheel)
    theta = theta_wrap(theta(:));
    n = size(colorWheel,1);
    theta_idx = theta / 360 * n;

    idx_floor = floor(theta_idx) + 1;
    idx_floor(idx_floor > n) = idx_floor(idx_floor > n) - n;

    idx_ceil = idx_floor + 1;
    idx_ceil(idx_ceil > n) = idx_ceil(idx_ceil > n) - n;

    frac = theta_idx - floor(theta_idx);
    base = colorWheel(idx_floor, :);
    next = colorWheel(idx_ceil, :);
    rgb = (1 - frac) .* base + frac .* next;
end

% -------------------------------------------------------------------------
function draw_fixation(win, display_params)
    center = mean(reshape(Screen('Rect', win),2,2),2)';
    radius = display_params.fixation_radiusPx;
    rect = [center - radius, center + radius];
    Screen('FillOval', win, display_params.fixation_color', rect);
end

% -------------------------------------------------------------------------
function vertices = equilateral_vertices(win, radius)
    if isscalar(win)
        rect = Screen('Rect', win);
    else
        rect = win;
    end
    [cx, cy] = RectCenter(rect);
    angles = deg2rad([90, 210, 330]);
    vertices = [cx + radius * cos(angles); cy + radius * sin(angles)];
end

% -------------------------------------------------------------------------
function rects = compute_patch_rects(vertices, radiusPx)
    rects = zeros(4, size(vertices,2));
    for ii = 1:size(vertices,2)
        rects(:,ii) = CenterRectOnPointd([0 0 2*radiusPx 2*radiusPx], vertices(1,ii), vertices(2,ii));
    end
end

% -------------------------------------------------------------------------
function show_instructions(display_params)
    win = display_params.window;
    Screen('FillRect', win, display_params.bgColor);
    draw_fixation(win, display_params);
    text = ['3-AFC oddity task\n\n' ...
        'Fixate at the center. Three color patches will appear for 500 ms,\n' ...
        'followed by a 500 ms mask. Press 1, 2, or 3 to report which patch\n' ...
        'was different in hue. Press ESC to abort.\n\n' ...
        'Press any key to begin.'];
    DrawFormattedText(win, text, 'center', 'center', [1 1 1]);
    Screen('Flip', win);
    KbStrokeWait;
end

% -------------------------------------------------------------------------
function cleanup_after_trial(win)
    sca;
    Screen('CloseAll');
end

% -------------------------------------------------------------------------
function value = getfield_with_default(S, path, default)
    value = default;
    if isempty(S)
        return;
    end
    node = S;
    for idx = 1:numel(path)
        key = path{idx};
        if isstruct(node) && isfield(node, key)
            node = node.(key);
            value = node;
        else
            value = default;
            return;
        end
    end
end

% -------------------------------------------------------------------------
function patchRadiusPx = estimatePatchRadius(V)
    if isfield(V, 'window')
        rect = Screen('Rect', V.window);
    elseif isfield(V, 'rect')
        rect = V.rect;
    else
        rect = [0 0 1024 768];
    end
    patchRadiusPx = round(min(rect(3:4)) * 0.05);
end

% -------------------------------------------------------------------------
function wheel = default_oklab_wheel()
    theta = (0:359)';
    L = 0.7 * ones(size(theta));
    C = 0.1 * ones(size(theta));
    a = C .* cosd(theta);
    b = C .* sind(theta);
    wheel = oklab_to_srgb(L, a, b);
    wheel = max(min(wheel,1),0);
end

% -------------------------------------------------------------------------
function srgb = oklab_to_srgb(L, a, b)
    % Basic OkLab to sRGB conversion.
    l_ = L + 0.3963377774*a + 0.2158037573*b;
    m_ = L - 0.1055613458*a - 0.0638541728*b;
    s_ = L - 0.0894841775*a - 1.2914855480*b;

    l = l_.^3;
    m = m_.^3;
    s = s_.^3;

    X =  1.2270138511*l - 0.5577999807*m + 0.2812561490*s;
    Y = -0.0405801784*l + 1.1122568696*m - 0.0716766787*s;
    Z = -0.0763812845*l - 0.4214819784*m + 1.5861632204*s;

    M = [ 3.2404542 -1.5371385 -0.4985314;
         -0.9692660  1.8760108  0.0415560;
          0.0556434 -0.2040259  1.0572252];
    srgb = [X Y Z] * M';
    srgb = apply_srgb_gamma(srgb);
end

% -------------------------------------------------------------------------
function srgb = apply_srgb_gamma(rgb)
    a = 0.055;
    srgb = zeros(size(rgb));
    idx = rgb <= 0.0031308;
    srgb(idx) = 12.92 * rgb(idx);
    srgb(~idx) = (1+a) * rgb(~idx).^(1/2.4) - a;
end

% -------------------------------------------------------------------------
function plot_thresholds(theta_h, sigma_hat, baseName)
    figure('Name',[baseName '_SigmaHat'],'Color','w');
    polarplot(deg2rad(theta_h), sigma_hat, 'o-','LineWidth',1.5);
    title('\sigma_h estimates per hub');
end

% -------------------------------------------------------------------------
function plot_smoothed_sigma(theta_dense, sigma_dense, baseName)
    figure('Name',[baseName '_SigmaSmooth'],'Color','w');
    plot(theta_dense, sigma_dense, 'LineWidth',1.5);
    xlabel('\theta (deg)');
    ylabel('\sigma(\theta)');
    grid on;
    title('Smoothed \sigma(\theta)');
end

% -------------------------------------------------------------------------
function plot_s_function(theta_dense, s_dense, baseName)
    figure('Name',[baseName '_sTheta'],'Color','w');
    plot(theta_dense, s_dense, 'LineWidth',1.5);
    xlabel('\theta (deg)');
    ylabel('s(\theta) = 1/\sigma(\theta)');
    grid on;
    title('Sensitivity function s(\theta)');
end

% -------------------------------------------------------------------------
function plot_warp(theta_dense, forwardValues, baseName)
    figure('Name',[baseName '_Warp'],'Color','w');
    plot(theta_dense, forwardValues,'LineWidth',1.5);
    xlabel('\theta (deg)');
    ylabel('W(\theta) (deg)');
    grid on;
    title('Perceptual warp W(\theta)');
end

