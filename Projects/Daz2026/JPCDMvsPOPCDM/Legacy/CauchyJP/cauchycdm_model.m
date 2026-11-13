function model = cauchycdm_model()
%CAUCHYCDM_MODEL H0 parameter layout for nine-condition Cauchy-CDM.

    model.name = "H0";
    model.description = "psi=-1 compiled; 9 condition kappas; " + ...
        "vnorm by set size; shared eta1/a/ter/st; eta2=exp(-6)";
    model.condLevels = ["S2C2NR", "S4C2NR", "S4C2R", ...
        "S4C4NR", "S6C2NR", "S6C2R", "S6C4NR", "S6C4R", "S6C6NR"];
    model.paramNames = ["vnormS2", "vnormS4", "vnormS6", ...
        "eta1", "a", "ter", "kappa_" + model.condLevels, "st"];
    % Hard boxes follow the supplied JP-CDM example. Eta1 starts at the
    % compiled numerical floor rather than the example's formal zero.
    model.P0 = [4, 4, 4, 0.6, 4, 0.25, 3*ones(1, 9), 0.15];
    model.lb = [0, 0, 0, 0.01, 0.5, 0, 0*ones(1, 9), 0];
    model.ub = [7.5, 7.5, 7.5, 4, 5, 1.5, 7.5*ones(1, 9), 0.7];
    model.index.vnorm = 1:3;
    model.index.eta1 = 4;
    model.index.a = 5;
    model.index.ter = 6;
    model.index.kappa = 7:15;
    model.index.st = 16;
    model.eta2 = exp(-6);
    model.psi = -1;
    model.nFree = numel(model.P0);
end
