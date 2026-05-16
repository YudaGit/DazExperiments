function [ ] = SaveFig( fig, savepath, saveon, dpi, dimensions, pdf )
% Script to either a) show a figure, pause processing and close after
% viewing or b) save a figure with a specified dpi 
    if ~exist('fig', 'var'), error('Error in f_SaveFig. fig (Figure) handle must exist.'); end
    if ~exist('savepath', 'var'), error('Error in f_SaveFig. savepath must be specified.'); end
    if ~exist('dpi', 'var'), dpi = 400; end
    if ~exist('savepath', 'var'), saveon=false; end
    if ~exist('dimensions', 'var'), dimensions=[0 0 20 10]; end % Note A4 Portrait is 21 cm x 29.7 so if you don't want scaling, fit it in this.
    if ~exist('pdf', 'var'), pdf = false; end
    % Check directory exists for saving
    dir = fileparts(char(savepath));
    if exist(dir,'dir') ~= 7; mkdir( dir ); end
    % If saving...
    if saveon
        % Set the dpi
        dpi = ['-r', num2str(dpi)];
        % Set page dimensions
        set( fig, 'PaperUnits', 'centimeters', 'PaperPosition', dimensions, 'PaperSize', dimensions(3:4));
        % Toggle if pdf vs png
        if ~pdf
            print( char(savepath) , '-dpng', dpi);
        else
            print( char(savepath) , '-dpdf', dpi);
        end
        close();
    else
        % show figure, and close after pause.
        pause;
        close()
    end
end