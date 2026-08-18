function build_cauchycdm_mex(vcpkgRoot)
%BUILD_CAUCHYCDM_MEX Build wrapped-Cauchy CDM core with static GSL.
%
% Requires Microsoft Visual C++ 2022 configured with `mex -setup C` and
% GSL installed by vcpkg for the x64-windows-static triplet.

    arguments
        vcpkgRoot (1,1) string = "C:\vcpkg"
    end

    thisDir = fileparts(mfilename('fullpath'));
    tripletRoot = fullfile(vcpkgRoot, 'installed', 'x64-windows-static');
    includeDir = fullfile(tripletRoot, 'include');
    libraryDir = fullfile(tripletRoot, 'lib');
    gslLibrary = fullfile(libraryDir, 'gsl.lib');
    cblasLibrary = fullfile(libraryDir, 'gslcblas.lib');
    sourceFile = fullfile(thisDir, 'vjp300rot.c');

    required = [sourceFile, fullfile(includeDir, 'gsl', 'gsl_sf_bessel.h'), ...
        gslLibrary, cblasLibrary];
    if any(~isfile(required))
        error('CauchyCDM:BuildDependencyMissing', ...
            'C source or static GSL dependency is missing under %s.', tripletRoot);
    end

    oldDir = cd(thisDir);
    cleanup = onCleanup(@() cd(oldDir));
    mex('-R2018a', ['-I' char(includeDir)], sourceFile, ...
        gslLibrary, cblasLibrary, '-output', 'vjp300rot');
    clear cleanup
    fprintf('Built %s\n', fullfile(thisDir, ['vjp300rot.' mexext]));
end
