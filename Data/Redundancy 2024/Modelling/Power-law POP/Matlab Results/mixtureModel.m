function logL = mixtureModel(params, dataBySetSize, setSizes)
    % params = [alpha1, alpha2, ..., alphaN, kappa]
    N = length(setSizes);         % Number of set sizes
    alphas = params(1:N);         % Separate alpha values for each set size
    kappa = params(N + 1);        % Shared kappa (concentration parameter)
    mu = 0;                       % Fixed mean (mu = 0)
    
    logL = 0;  % Initialize log-likelihood
    
    for i = 1:N
        alpha = alphas(i);        % Mixture proportion for the current set size
        data = dataBySetSize{i};  % Data for the current set size
        
        % Uniform distribution over the circular space [0, 2*pi]
        uniformPDF = 1 / (2 * pi);
        
        % Compute the von Mises PDF for each data point with mu fixed at 0
        vonMisesPDFValues = vonMisesPDF(data, mu, kappa);
        
        % Mixture model PDF
        mixturePDF = alpha * uniformPDF + (1 - alpha) * vonMisesPDFValues;
        
        % Accumulate the log-likelihood
        logL = logL - sum(log(mixturePDF));  % Negative log-likelihood
    end
end


function pdf = vonMisesPDF(x, mu, kappa)
    % x: data points (angles)
    % mu: mean of the distribution (here, it will always be 0)
    % kappa: concentration parameter (inverse of variance)
    pdf = exp(kappa * cos(x - mu)) / (2 * pi * besseli(0, kappa));
end