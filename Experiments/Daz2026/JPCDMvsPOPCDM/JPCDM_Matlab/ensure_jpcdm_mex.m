function rebuilt = ensure_jpcdm_mex()
%ENSURE_JPCDM_MEX Build the JP MEX core when missing or older than source.

    thisDir = fileparts(mfilename('fullpath'));
    sourceFile = fullfile(thisDir, 'vjp300rot.c');
    mexFile = fullfile(thisDir, ['vjp300rot.' mexext]);
    needsBuild = ~isfile(mexFile);
    if ~needsBuild
        sourceInfo = dir(sourceFile);
        mexInfo = dir(mexFile);
        needsBuild = mexInfo.datenum < sourceInfo.datenum;
    end
    if needsBuild
        fprintf('JP-CDM MEX is missing or stale; rebuilding.\n');
        addpath(thisDir);
        build_jpcdm_mex;
        rebuilt = true;
    else
        rebuilt = false;
    end
    if exist('vjp300rot', 'file') ~= 3
        error('JPCDM:MexUnavailable', 'Compiled vjp300rot MEX is unavailable.');
    end
end
