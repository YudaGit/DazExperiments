 function build_test_mex()
%BUILD_TEST_MEX Build local POPvJPvCauchy MEX cores.
%   Run this from MATLAB before fitting if which(..., '-all') points to an
%   older sibling-folder MEX.

    thisDir = fileparts(mfilename('fullpath'));
    oldDir = pwd;
    cleanup = onCleanup(@() cd(oldDir));

    addpath(thisDir, '-begin');
    cd(thisDir);

    sources = ["vpop300rot.c", "vjp300rot.c", "vcau300rot.c"];
    mexNames = ["vpop300rot", "vjp300rot", "vcau300rot"];

    for i = 1:numel(sources)
        mexFile = fullfile(thisDir, [char(mexNames(i)), '.', mexext]);
        sourceFile = fullfile(thisDir, char(sources(i)));
        needsBuild = ~exist(mexFile, 'file') || ...
            dir(sourceFile).datenum > dir(mexFile).datenum;

        if needsBuild
            fprintf('Building %s from %s.\n', mexFile, sourceFile);
            try
                mex('-R2018a', char(sources(i)), '-lgsl', '-lgslcblas', '-lm');
            catch
                mex('-R2018a', char(sources(i)), ...
                    '-I/opt/homebrew/opt/gsl/include', ...
                    '-L/opt/homebrew/opt/gsl/lib', ...
                    '-lgsl', '-lgslcblas', '-lm');
            end
        else
            fprintf('%s is up to date.\n', mexFile);
        end
    end

    clear vpop300rot vjp300rot vcau300rot;
    rehash toolboxcache;

    fprintf('\nResolved MEX paths:\n');
    which vpop300rot -all
    which vjp300rot -all
    which vcau300rot -all
end
