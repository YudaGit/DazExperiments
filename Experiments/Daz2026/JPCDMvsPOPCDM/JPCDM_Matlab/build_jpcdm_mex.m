function build_jpcdm_mex(gslRoot)
%BUILD_JPCDM_MEX Build JP-CDM core using MATLAB's configured C compiler.

    arguments
        gslRoot (1,1) string = ""
    end

    thisDir = fileparts(mfilename('fullpath'));
    sourceFile = fullfile(thisDir, 'vjp300rot.c');
    oldDir = cd(thisDir);
    cleanup = onCleanup(@() cd(oldDir));
    if gslRoot == ""
        gslRoot = detect_gsl_root();
    end
    includeDir = fullfile(gslRoot, 'include');
    libraryDir = fullfile(gslRoot, 'lib');
    if ~isfile(fullfile(includeDir, 'gsl', 'gsl_sf_bessel.h'))
        error('JPCDM:BuildDependencyMissing', ...
            'Could not find GSL headers under %s.', includeDir);
    end
    if ispc
        error('JPCDM:BuildNotConfigured', ...
            ['Windows static-GSL build flags vary by machine. Use the ', ...
             'Cauchy build script as a template or compile vjp300rot.c ', ...
             'with GSL and gslcblas on the MATLAB path.']);
    else
        mex('-R2018a', ['-I' char(includeDir)], ...
            ['-L' char(libraryDir)], sourceFile, ...
            '-lgsl', '-lgslcblas', '-lm', ...
            '-output', 'vjp300rot');
    end
    clear cleanup
    fprintf('Built %s\n', fullfile(thisDir, ['vjp300rot.' mexext]));
end

function gslRoot = detect_gsl_root()
    candidates = [ ...
        "/opt/homebrew/opt/gsl", ...
        "/usr/local/opt/gsl", ...
        "/opt/homebrew/Cellar/gsl/2.8", ...
        "/usr/local/Cellar/gsl/2.8"];
    for i = 1:numel(candidates)
        if isfile(fullfile(candidates(i), 'include', 'gsl', ...
                'gsl_sf_bessel.h'))
            gslRoot = candidates(i);
            return
        end
    end
    error('JPCDM:BuildDependencyMissing', ...
        ['GSL was not found. Install it with Homebrew (`brew install gsl`) ', ...
         'or call build_jpcdm_mex("/path/to/gsl").']);
end
