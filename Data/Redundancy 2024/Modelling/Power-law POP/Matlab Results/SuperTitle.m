function [ ] = SuperTitle( Text, FontSize, YPos )
%UNTITLED3 Summary of this function goes here
%   Detailed explanation goes here

    if ~exist('FontSize', 'var'),  FontSize=16; end
    if ~exist('YPos', 'var'),  YPos=.925; end

    axes( 'Position', [0, YPos, 1, 0.05] ) ;
    set( gca, 'Color', 'None', 'XColor', 'None', 'YColor', 'None' ) ;
    text( 0.5, 0, ['\bf ', Text], 'FontSize', FontSize, ...
          'HorizontalAlignment', 'Center', 'VerticalAlignment', 'Bottom', 'Interpreter', 'LaTeX' ) ;

end

