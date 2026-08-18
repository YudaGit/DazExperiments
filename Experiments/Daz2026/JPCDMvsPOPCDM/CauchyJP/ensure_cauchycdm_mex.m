function rebuilt = ensure_cauchycdm_mex()
%ENSURE_CAUCHYCDM_MEX Build the MEX core when missing or older than source.

    thisDir=fileparts(mfilename('fullpath'));
    sourceFile=fullfile(thisDir,'vjp300rot.c');
    mexFile=fullfile(thisDir,['vjp300rot.' mexext]);
    needsBuild=~isfile(mexFile);
    if ~needsBuild
        sourceInfo=dir(sourceFile);
        mexInfo=dir(mexFile);
        needsBuild=mexInfo.datenum<sourceInfo.datenum;
    end
    if needsBuild
        fprintf('Cauchy-CDM MEX is missing or stale; rebuilding.\n');
        build_cauchycdm_mex;
        rebuilt=true;
    else
        rebuilt=false;
    end
    if exist('vjp300rot','file')~=3
        error('CauchyCDM:MexUnavailable','Compiled vjp300rot MEX is unavailable.');
    end
end
