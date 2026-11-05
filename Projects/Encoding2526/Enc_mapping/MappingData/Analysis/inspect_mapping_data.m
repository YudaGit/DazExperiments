% Inspect mapping checkpoints without modifying raw data.
dataDir = fileparts(fileparts(mfilename('fullpath')));
files = dir(fullfile(dataDir, 'mapping_*.mat'));
inventory = table();
for i = 1:numel(files)
    d = load(fullfile(files(i).folder, files(i).name));
    main = d.expTrials; practice = d.practiceTrials;
    complete = isfield(d,'sessionComplete') && isequal(d.sessionComplete,true);
    row = table(string(files(i).name), complete, height(practice), sum(practice.Completed), ...
        height(main), sum(main.Completed), sum(main.TimedOut & main.Completed), ...
        sum(main.Completed & ~main.TimedOut & isfinite(main.SignedErrorDeg)), ...
        'VariableNames', {'File','SessionComplete','PracticePlanned','PracticeCompleted', ...
        'MainPlanned','MainCompleted','MainTimeouts','MainFiniteResponses'});
    inventory = [inventory; row];
    if complete && all(main.Completed) && all(practice.Completed)
        writetable(main, fullfile(fileparts(mfilename('fullpath')), 'completed_main_trials.csv'));
        writetable(practice, fullfile(fileparts(mfilename('fullpath')), 'completed_practice_trials.csv'));

    end
end
writetable(inventory, fullfile(fileparts(mfilename('fullpath')), 'session_inventory.csv'));
disp(inventory);
