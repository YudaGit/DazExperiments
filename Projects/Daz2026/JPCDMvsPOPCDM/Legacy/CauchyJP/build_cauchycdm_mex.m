function build_cauchycdm_mex(gslRoot)
%BUILD_CAUCHYCDM_MEX Build wrapped-Cauchy CDM core with GSL.
%
% On Windows, pass a vcpkg root containing installed/x64-windows-static.
% On macOS/Linux, pass a GSL root or let the helper detect Homebrew GSL.

    arguments
        gslRoot (1,1) string = ""
    end

    thisDir = fileparts(mfilename('fullpath'));
    sourceFile = fullfile(thisDir, 'vjp300rot.c');
    if gslRoot == ""
        gslRoot = detect_gsl_root();
    end

    if ispc
        tripletRoot = fullfile(gslRoot, 'installed', 'x64-windows-static');
        includeDir = fullfile(tripletRoot, 'include');
        libraryDir = fullfile(tripletRoot, 'lib');
        gslLibrary = fullfile(libraryDir, 'gsl.lib');
        cblasLibrary = fullfile(libraryDir, 'gslcblas.lib');
        required = [sourceFile, fullfile(includeDir, 'gsl', ...
            'gsl_sf_bessel.h'), gslLibrary, cblasLibrary];
    else
        includeDir = fullfile(gslRoot, 'include');
        libraryDir = fullfile(gslRoot, 'lib');
        required = [sourceFile, fullfile(includeDir, 'gsl', ...
            'gsl_sf_bessel.h')];
    end

    if any(~isfile(required))
        error('CauchyCDM:BuildDependencyMissing', ...
            'C source or GSL dependency is missing under %s.', gslRoot);
    end

    oldDir = cd(thisDir);
    cleanup = onCleanup(@() cd(oldDir));
    if ispc
        mex('-R2018a', ['-I' char(includeDir)], sourceFile, ...
            gslLibrary, cblasLibrary, '-output', 'vjp300rot');
    else
        mex('-R2018a', ['-I' char(includeDir)], ...
            ['-L' char(libraryDir)], sourceFile, ...
            '-lgsl', '-lgslcblas', '-lm', '-output', 'vjp300rot');
    end
    clear cleanup
    fprintf('Built %s\n', fullfile(thisDir, ['vjp300rot.' mexext]));
end

function gslRoot = detect_gsl_root()
    if ispc
        gslRoot = "C:\vcpkg";
        return
    end
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
    error('CauchyCDM:BuildDependencyMissing', ...
        ['GSL was not found. Install it with Homebrew (`brew install gsl`) ', ...
         'or call build_cauchycdm_mex("/path/to/gsl").']);
end
