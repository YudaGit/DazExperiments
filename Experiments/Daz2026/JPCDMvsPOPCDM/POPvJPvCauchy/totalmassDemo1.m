% Demonstrate why I think totalmass may need to use (nw + 1), not nw.
%   Gt is allocated as (nw + 1) rows by sz columns.
%   Rows 1:nw are unique angular bins.
%   Row nw+1 is the wraparound duplicate row.
%   For totalmass calculation, C code uses nw instead of nw+1
%   My question is if using nw makes totalmass calculation reads the wrong
%   rows.


clear; clc;

nw = 50;
sz = 300;

Gt = zeros(nw + 1, sz);

%replicate the C wrap around loop
for k = 1:sz
    for i = 1:nw
        Gt(i, k) = 10 * k + i;
    end

    % Close the domain as done in C, here +pi duplicates -pi.
    Gt(nw + 1, k) = Gt(1, k);
end


testSum = 0;
currentSum = 0;

for i = 1:nw
    for k = 2:sz % for matlab 1-based indexing
        % test sum uses nw+1 here
        testSum = testSum + ...
            (Gt((nw + 1) * (k - 1) + i) + ...
            Gt((nw + 1) * (k - 2) + i))/2.0;
        
        % current C total sum uses nw
        currentSum = currentSum + ...
            (Gt((nw) * (k - 1) + i) + ...
            Gt((nw) * (k - 2) + i))/2.0;
    end
end

% cell values

for i = 1:3
    for k = 2:10
        matrixValue = Gt(i, k);

        % index with (nw+1) for totalmass  
        testIndex = (nw + 1) * (k - 1) + i;
        testCellValue = Gt(testIndex);

        % Current C index with nw for totalmass
        currentIndex = nw * (k - 1) + i;
        currentCellValue = Gt(currentIndex);

        fprintf('i=%d k=%d | matrix=%4d | correct idx=%3d val=%4d | wrong idx=%3d val=%4d\n', ...
            i, k, matrixValue, testIndex, testCellValue, ...
            currentIndex, currentCellValue);
    end
end

%Printed matrix cell value at i,k matches index with (nw+1)