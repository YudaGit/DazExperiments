% KbCheck learning

clear all

KbName('UnifyKeyNames');
disp('Press ESC to quit.');

while true
    [keyIsDown, ~, keyCode] = KbCheck;
    if keyIsDown
        key = KbName(find(keyCode, 1));
        disp(['Key pressed: ', key]);

        if strcmpi(key, 'ESCAPE')
            break;
        end
    end
    WaitSecs(0.05);  % limit CPU load
end