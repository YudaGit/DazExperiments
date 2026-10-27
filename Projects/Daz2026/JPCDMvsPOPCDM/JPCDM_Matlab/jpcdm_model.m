function model = jpcdm_model(hypothesis)
%JPCDM_MODEL Current H0a/H0b layouts for JP-CDM comparison fits.

    arguments
        hypothesis (1,1) string {mustBeMember(hypothesis, ["H0a","H0b"])}
    end

    model.name = hypothesis;
    model.condLevels = ["S2C2NR", "S4C2NR", "S4C2R", ...
        "S4C4NR", "S6C2NR", "S6C2R", "S6C4NR", "S6C4R", "S6C6NR"];
    model.eta2 = exp(-6);
    model.nCond = numel(model.condLevels);
    model.index.vnorm = 1:3;
    model.index.eta1 = 4;
    model.index.a = 5;
    model.index.ter = 6;
    model.index.front = 7:15;
    model.index.st = 16;
    model.index.sharedFront = 17;

    if hypothesis == "H0a"
        model.description = "9 condition psi values; shared kappa; " + ...
            "vnorm by set size; shared eta1/a/ter/st; eta2=exp(-6)";
        model.paramNames = ["vnormS2", "vnormS4", "vnormS6", ...
            "eta1", "a", "ter", "psi_" + model.condLevels, ...
            "st", "kappa"];
        model.P0 = [4, 4, 4, 0.6, 4, 0.25, -0.25*ones(1, 9), 0.15, 3];
        model.lb = [0, 0, 0, 0.01, 0.5, 0, -1*ones(1, 9), 0, 0];
        model.ub = [7.5, 7.5, 7.5, 4, 5, 1.5, ones(1, 9), 0.7, 7.5];
        model.freeParameter = "psi";
    else
        model.description = "9 condition kappa values; shared psi; " + ...
            "vnorm by set size; shared eta1/a/ter/st; eta2=exp(-6)";
        model.paramNames = ["vnormS2", "vnormS4", "vnormS6", ...
            "eta1", "a", "ter", "kappa_" + model.condLevels, ...
            "st", "psi"];
        model.P0 = [4, 4, 4, 0.6, 4, 0.25, 3*ones(1, 9), 0.15, -0.25];
        model.lb = [0, 0, 0, 0.01, 0.5, 0, zeros(1, 9), 0, -1];
        model.ub = [7.5, 7.5, 7.5, 4, 5, 1.5, 7.5*ones(1, 9), 0.7, 1];
        model.freeParameter = "kappa";
    end

    model.nFree = numel(model.P0);
end
