function report = validate_cauchycdm()
%VALIDATE_CAUCHYCDM Numerical and interface checks for compiled Cauchy-CDM.

    ensure_cauchycdm_mex;
    tmax=3;
    P=[6,.5,exp(-6),6,2,.25,.2];
    [T,Gt,Theta]=cauchycdm2(P,tmax);
    dtheta=Theta(2)-Theta(1); dt=T(2)-T(1);
    keep=T>=.3&T<=3;
    retainedMass=sum(max(Gt(:,keep),0),'all')*dtheta*dt;
    if ~(all(isfinite(Gt),'all')&&retainedMass>.95&&retainedMass<1.01)
        error('CauchyCDM:MassCheck','Forward density failed mass/finite check.');
    end

    angleP=sum(max(Gt(:,keep),0),2)*dt*dtheta/retainedMass;
    mirrorIndex=mod(-(0:numel(Theta)-1),numel(Theta))+1;
    symmetryError=max(abs(angleP-angleP(mirrorIndex)));
    if symmetryError>1e-8
        error('CauchyCDM:SymmetryCheck','Symmetry error %.3g.',symmetryError);
    end

    broad=P; broad(5)=0.5;
    narrow=P; narrow(5)=4;
    broadTail=tail_mass(broad,tmax);
    narrowTail=tail_mass(narrow,tmax);
    if broadTail<=narrowTail
        error('CauchyCDM:KappaCheck','Increasing kappa did not reduce tail mass.');
    end

    noSt=P; noSt(7)=0;
    [Traw,Graw]=cauchycdm2(noSt,tmax);
    m=round(P(7)/(Traw(2)-Traw(1)));
    kernel=ones(1,m)/m;
    loopGt=zeros(size(Graw));
    for rowIndex=1:size(Graw,1)
        rowDensity=conv(Graw(rowIndex,:),kernel);
        loopGt(rowIndex,:)=rowDensity(1:size(Graw,2));
    end
    convolutionError=max(abs(Gt-loopGt),[],'all');
    if convolutionError>1e-12
        error('CauchyCDM:ConvolutionCheck', ...
            'Matrix convolution differs from row-wise reference by %.3g.', ...
            convolutionError);
    end

    rejectedShapeInput=false;
    try
        vjp300rot([6,2,.5,exp(-6),0,-1,1,6],tmax,1e-12);
    catch
        rejectedShapeInput=true;
    end
    if ~rejectedShapeInput
        error('CauchyCDM:InterfaceCheck','MEX accepted an obsolete psi input.');
    end

    tic; cauchycdm2(P,tmax); first=toc;
    tic; for i=1:20,cauchycdm2(P,tmax);end; cached=toc/20;
    report=struct('retainedMass',retainedMass,'symmetryError',symmetryError, ...
        'broadTail',broadTail,'narrowTail',narrowTail, ...
        'convolutionError',convolutionError, ...
        'firstSeconds',first,'cachedSeconds',cached, ...
        'psiCompiled',-1,'mexFile',which('vjp300rot'));
    disp(report);
end

function mass=tail_mass(P,tmax)
    [T,Gt,Theta]=cauchycdm2(P,tmax);
    dtheta=Theta(2)-Theta(1); dt=T(2)-T(1);
    keep=T>=.3&T<=3; Gt=max(Gt(:,keep),0);
    total=sum(Gt,'all')*dtheta*dt;
    mass=sum(Gt(abs(Theta)>45*pi/180,:),'all')*dtheta*dt/total;
end
