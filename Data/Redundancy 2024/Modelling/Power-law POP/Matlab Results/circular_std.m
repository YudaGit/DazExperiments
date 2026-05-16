function [std_circ, variance, SEr, SEs] = circular_std(theta)
    % theta is the angular data in radians
    n = length(theta); % Number of data points
    C = sum(cos(theta)); % Sum of cosines
    S = sum(sin(theta)); % Sum of sines
    R = sqrt(C^2 + S^2) / n; % Mean resultant length
    std_circ = sqrt(-2 * log(R)); % Circular standard deviation
    variance = 1 - R;
    SEr = sqrt(1 - R ^ 2) / sqrt(n);
    SEs = (1 / (R * sqrt(-2 * log(R)))) * SEr;
end