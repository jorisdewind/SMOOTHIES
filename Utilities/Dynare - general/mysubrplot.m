%%  My subplot version of Dynare's rplot
%
% Input:
%   nrow:     number of rows in subplot
%   ncol:     number of columns in subplot
%   vars:     cell array with variables to be plotted (in row order;
%             use '' to skip a subplot)
%   labs:     cell array with associated labels (if labs is missing,
%             vars will be used instead)
%   period:   sample period to be plotted (format is [start end]; if
%             period is missing, full sample period will be plotted)
%   nomax:    true to avoid maximization of figure
%
%       Joris de Wind (February 2016)
%==========================================================================

function mysubrplot(nrow,ncol,vars,labs,period,nomax)

% initialize figure
hfs = figure;

% get subplot positions
pos = zeros(4,nrow*ncol);
for i = 1:nrow,
    for j = 1:ncol,
        ind = (i-1)*ncol+j;
        s = subplot(nrow,ncol,ind);
        pos(:,ind) = get(s,'Position')';
        delete(s);
    end
end

% construct rplot figures and copy them to subplot positions
if ~exist('labs','var'),
    labs = vars;
end
for i = 1:length(vars),
    if strcmp(vars{i},''),
        continue
    end
    rplot(vars{i})
    hf = gcf;
    set(get(gca,'children'),'LineWidth',2,'Color','red'), grid on
    title(labs{i},'Interpreter','latex','Fontsize',14)
    if exist('period','var') && isnumeric(period),
        set(gca,'xlim',period)
    end
    haxs = copyobj(gca,hfs); set(haxs,'Position',pos(:,i));
    close(hf)
end

% maximize figure
if ~exist('nomax','var') || ~nomax,
    drawnow; jFig = get(handle(gcf),'JavaFrame'); jFig.setMaximized(true);
end