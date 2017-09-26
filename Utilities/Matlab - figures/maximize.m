function maximize(hFig)

if nargin < 1, hFig = gcf; end

drawnow; jFig = get(handle(hFig),'JavaFrame'); jFig.setMaximized(true);

end