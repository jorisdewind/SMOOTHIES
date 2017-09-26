    %% Exact Nonlinear and Non-Gaussian Kalman Smoother Made Easy in Dynare
%   - This version is fully automated!!
%
%   Example nonlinear state space model:
%       y(t) = cos( x(t)^2 + uy(t) ) * exp( z(t) ),      uy(t) ~ N(0, hy^2)
%       x(t) = (1 - rhox) * mux + rhox * x(t-1) + ex(t), ex(t) ~ N(0, qx^2)
%       z(t) = (1 - rhoz) * muz + rhoz * z(t-1) + ez(t), ez(t) ~ N(0, qz^2)
%       x(0), z(0) are given
%
%   Goal:
%       Find the mode of x given y (the parameters are known)
%
%       Joris de Wind (December 2016), email: jorisdewind@gmail.com
%--------------------------------------------------------------------------

%Cleaning
clear; close all; clc

%Changing display format
format shortG;

%Adding utilities to path
addpath(genpath(fullfile('..','Utilities')))

%% Parameters
%--------------------------------------------------------------------------

%Parameter values
rhox = 0.95;        %State equation x, autoregressive coefficient
mux  = 1;           %State equation x, constant
rhoz = -0.75;      	%State equation z, autoregressive coefficient
muz  = -1;          %State equation z, constant
hy   = 0.25;        %Standard deviation measurement error
qx   = 0.1;         %Standard deviation state innovations x
qz   = 0.05;        %Standard deviation state innovations z

save parameters rhox mux rhoz muz hy qx qz;     %Save parameter values for Dynare

%Number of time periods
T = 200;

%% Generating artificial data
%--------------------------------------------------------------------------

%Generating disturbances
randn('state',30101985);                                         %#ok<RAND>
uy = [NaN ; hy * randn(T,1)];
ex = [NaN ; qx * randn(T,1)];
ez = [NaN ; qz * randn(T,1)];

%Allocating memory and initialization
x = zeros(T+1,1);	x(1) = mux;     %Timing: x(1) is x0, x(2) = x1, etc.
z = zeros(T+1,1);	z(1) = muz;     %Timing: z(1) is z0, z(2) = z1, etc.
y = zeros(T+1,1);	y(1) = NaN;     %Timing: y(1) does not exist, y(2) is y1

%Generating artificial data
for i = 1:T,
    x(i+1) = (1 - rhox) * mux + rhox * x(i) + ex(i+1);      %State equation x
    z(i+1) = (1 - rhoz) * muz + rhoz * z(i) + ez(i+1);      %State equation z
    y(i+1) = cos( x(i+1)^2 + uy(i+1) ) * exp( z(i+1) );     %Measurement equation
end

%% Main procedure
%--------------------------------------------------------------------------

%Preliminary run of Dynare
dynare dyna_cos_model notmpterms noclearall                 %No temp terms option

%0. User settings: choose here the list of disturbances and observables
%----------------------------------------------------------------------

%List of disturbances that join the party (as cell array)
which_shocks = 'all_shocks';                            %User setting!!
switch which_shocks
    case 'all_shocks'	%Default
        list_of_shocks = mat2cell(M_.exo_names, ...
            ones(1,size(M_.exo_names,1)),size(M_.exo_names,2));
        list_of_shocks = cellfun(@strtrim,list_of_shocks,'UniformOutput',false);
        nshocks = size(list_of_shocks,1);
    case 'subset_of_shocks'
        list_of_shocks = {};                            %User setting!!
        nshocks = size(list_of_shocks,1);
end

%List of observables (as cell array)
list_of_observables = {'yy'};                           %User setting!!
nobservables = length(list_of_observables);

%List of unobservables
list_of_variables = mat2cell(M_.endo_names, ...
    ones(1,size(M_.endo_names,1)),size(M_.endo_names,2));
list_of_variables = cellfun(@strtrim,list_of_variables,'UniformOutput',false);
list_of_unobservables = setdiff(list_of_variables,list_of_observables);

%1. Construct log pdf of disturbances
%------------------------------------

%Construct log pdf of disturbances
logpdf = cell(1,nshocks);
for i = 1:nshocks,
    logpdf{i} = sprintf('- %s^2 / ( 2 * %d ) ', ...         %Assume normal distributed disturbances; other distributions could be supported as well
        list_of_shocks{i,:}, ...
        M_.Sigma_e( ...
        get_exo_index(list_of_shocks{i,:}), ...
        get_exo_index(list_of_shocks{i,:})));
end
logpdf = cell2mat(logpdf);

%2. Construct constraints / model equations
%------------------------------------------

%Extract code from Dynare model file
fid = fopen('dyna_cos_model.mod','r');
code = fscanf(fid,'%c');
code = regexprep(code,'(\s*%.*?(\n|$)|\s*(\n|$))+','\n');   %Remove comments and blank lines
code = regexprep(code,'(^\n|\n$)','');                      %Remove blank lines at beginning and end of code
fclose(fid);

%--------------------------------------------------------------------------
%Old stuff:
% %Extract all lines from Dynare model file and put in cell array
% fid = fopen('dyna_cos_model.mod','r');
% lines = textscan(fid,'%s','delimiter','\n');
% lines = lines{1};
% lines = regexprep(lines,'\s*%.*','');     %Remove comments (to make text manipulation more robust)
% nlines = length(lines);
% fclose(fid);
%--------------------------------------------------------------------------

%Construct constraints
nequations = size(M_.endo_names,1);
equations = cell(1,nequations);
model_block = cell2mat(regexp(code,'model;.*?end;','match'));
lhs = regexp(model_block,';\n?(.*?)=','tokens');
rhs = regexp(model_block,'=(.*?);','tokens');
for i = 1:nequations,
    equations{i} = [sprintf('+ lm_%i * ( ( ',i),lhs{i}{1},') - (',rhs{i}{1},' ) ) '];   %Also multiply with Lagrangian multipliers
end
equations = cell2mat(equations);

%3. Construct Lagrangian function (log likelihood function s.t. constraints)
%---------------------------------------------------------------------------

loglik = ['loglik = ',logpdf,equations,sprintf(';\n')];

%4. Replace variable declarations
%--------------------------------

%Replace var declaration (only a single var block is allowed in the original Dynare model file)
var_declaration = 'var';
for i = 1:length(list_of_unobservables),    %Unobservables
    var_declaration = [var_declaration,' ',list_of_unobservables{i}]; %#ok<AGROW>
end
for i = 1:length(list_of_shocks),           %Shocks that join the party
    var_declaration = [var_declaration,' ',list_of_shocks{i}]; %#ok<AGROW>
end
for i = 1:nequations,                       %Lagrangian multipliers
    var_declaration = [var_declaration,' ',sprintf('lm_%i',i)]; %#ok<AGROW>
end
var_declaration = [var_declaration,' loglik;'];
code = regexprep(code,'var .*?;',var_declaration);

%Replace varexo declaration (only a single varexo block is allowed in the original Dynare model file)
varexo_declaration = 'varexo';
for i = 1:size(M_.exo_names,1),             %Shocks that don't join the party
    if ismember(strtrim(M_.exo_names(i,:)),list_of_shocks), continue, end
    varexo_declaration = [varexo_declaration,' ',strtrim(M_.exo_names(i,:))]; %#ok<AGROW>
end
for i = 1:length(list_of_observables),      %Observables
    varexo_declaration = [varexo_declaration,' ',list_of_observables{i}]; %#ok<AGROW>
end
varexo_declaration = [varexo_declaration,';'];
code = regexprep(code,'varexo .*?;',varexo_declaration);

%Delete entire shocks block
code = regexprep(code,'\n?shocks;.*?end;','');

%5. Construct extra equations
%----------------------------

%In this step just create some auxiliary equations to be replaced below in
%a later step:
%   - for each participating shock an optimality condition (nshocks)
%   - for each unobservable variable an optimality condition (nequations - nobservables)
%   - the Lagrangian function (log likelihood function s.t. constraints)

equations_extra = cell(1,nequations-nobservables+nshocks+1);
for i = 1:nshocks,
    equations_extra{i} = sprintf('%s = 0;\n',list_of_shocks{i});
end
for i = 1:nequations-nobservables,
    equations_extra{i+nshocks} = sprintf('lm_%i = 0;\n',i);
end
equations_extra{end} = loglik;
code = regexprep(code,'(model;.*?)(end;)',['$1',cell2mat(equations_extra),'$2']);

%6. Construct new Dynare model file with Lagrangian function
%-----------------------------------------------------------

fid = fopen('dyna_cos_model_with_lagrangian.mod','w');
fprintf(fid,'%s',code);
fclose(fid);

%7. Construct first-order conditions
%-----------------------------------

%Run Dynare
dynare dyna_cos_model_with_lagrangian noclearall notmpterms	%No temp terms option

%List of required first-order conditions
% - list of shocks
% - list of unobservable variables
% - equation number of Lagrangian function

list_of_focs = [list_of_shocks;list_of_unobservables];
code_after_loglik = regexp(code,'model;.*?loglik(.*?)end;','tokens');
loglik_equation_number = size(M_.endo_names,1)- ...
    length(regexp(code_after_loglik{1}{1},';'))+1;

%First-order conditions
focs = cell(1,length(list_of_focs));
for i = 1:length(focs),
    
    %Partial derivative with respect to previous period variables, lead by one period
    foc_previous = extract_element_jacobian('dyna_cos_model_with_lagrangian_dynamic.m', ...
        ['d',num2str(loglik_equation_number),'d',list_of_focs{i},'p'],M_);
    foc_previous = regexprep(foc_previous,'(\w\s*\()([\+\-]?\d*)(\))', ...
        '$1${num2str(eval([$2,''+1'']))}$3'); %Lead by one period
    
    %Partial derivative with respect to current period variables
    foc_current = extract_element_jacobian('dyna_cos_model_with_lagrangian_dynamic.m', ...
        ['d',num2str(loglik_equation_number),'d',list_of_focs{i},'c'],M_);
    
    %Partial derivative with respect to next period variables, lagged by one period
    foc_next = extract_element_jacobian('dyna_cos_model_with_lagrangian_dynamic.m', ...
        ['d',num2str(loglik_equation_number),'d',list_of_focs{i},'n'],M_);
    foc_next = regexprep(foc_next,'(\w\s*\()([\+\-]?\d*)(\))', ...
        '$1${num2str(eval([$2,''-1'']))}$3'); %Lag by one period
    
    %Combine partial derivatives into first-order conditions
    foc_previous = regexp(foc_previous,'=(.*);','tokens');
    foc_current = regexp(foc_current,'=(.*);','tokens');
    foc_next = regexp(foc_next,'=(.*);','tokens');
    focs{i} = [foc_previous{1}{1},' + ',foc_current{1}{1},' + ',foc_next{1}{1},sprintf(' = 0;\n')];
    
end

%8. Construct final Dynare model file
%------------------------------------

%Extract code from Dynare model file with Lagrangian function
fid = fopen('dyna_cos_model_with_lagrangian.mod','r');
code = fscanf(fid,'%c');
fclose(fid);

%Replace auxiliary equations by first-order conditions
code = regexprep(code,regexptranslate('escape',cell2mat(equations_extra)),cell2mat(focs));
code = regexprep(code,'(var .*?)( ?loglik)(.*?;)','$1$3');  %Delete loglik from var declaration

%Add commands
add_commands = sprintf(['\n', ...
    'initval_file(filename = data);\n', ...
    'options_.dynatol.f = 1E-12;\n', ...
    'simul(periods = @{T}, stack_solve_algo = 0, maxit = 1000);']);

%Construct final Dynare model file
fid = fopen('dyna_cos_model_final.mod','w');
fprintf(fid,'%s',code);
fprintf(fid,'%s',add_commands);
fclose(fid);

%9. Prepare data.mat for the initval_file Dynare function
%--------------------------------------------------------

%   - default values for initial guess
%   - values for observables
%   - initial and terminal conditions
%   - initial guess

%Default values for initial guess
for i = 1:size(M_.endo_names,1), eval([strtrim(M_.endo_names(i,:)),' = zeros(T+2,1);']); end
for i = 1:size(M_.exo_names,1), eval([strtrim(M_.exo_names(i,:)),' = zeros(T+2,1);']); end

%Values for observables
yy = [y; NaN];                                              %User setting!!

%Initial and terminal conditions as well as initial guess
xx = ones(T+2,1)*mux;       xx(1) = mux;                    %User setting!!
zz = ones(T+2,1)*muz;       zz(1) = muz;                    %User setting!!

%Saving
eval(['save(''data'',''',strtrim(M_.endo_names(1,:)),''')']);
for i = 2:size(M_.endo_names,1), eval(['save(''data'',''',strtrim(M_.endo_names(i,:)),''',''-append'')']); end
for i = 1:size(M_.exo_names,1), eval(['save(''data'',''',strtrim(M_.exo_names(i,:)),''',''-append'')']); end

%10. Run exact Kalman smoother
%-----------------------------

%Running Dynare
eval(sprintf(... %Final run of Dynare
    'dynare dyna_cos_model_final noclearall notmpterms -DT=%i;',T))
clean_dynare('dyna_cos_model','temp',true)
delete data.mat
delete parameters.mat

%Extracting the smoothed latent state variables from the Dynare output
a_x = oo_.endo_simul(get_endo_index('xx'),1:end-1)';
a_z = oo_.endo_simul(get_endo_index('zz'),1:end-1)';

%11. Plotting results
%--------------------

%Plotting
figure('Name',...
    'Nonlinear smoothing problem: smoothed versus latent state variables')
plot(1:T,y(2:T+1),'Marker','*','MarkerSize',3,'LineWidth',1,'LineStyle','-.')
hold all
plot(0:T,x,'Marker','*','MarkerSize',4,'LineWidth',1,'LineStyle','-')
plot(0:T,z,'Marker','*','MarkerSize',4,'LineWidth',1,'LineStyle','-')
plot(0:T,a_x,'LineWidth',2)
plot(0:T,a_z,'LineWidth',2)
axis([0 200 -1.5 2])
title('\bf{Nonlinear smoothing problem: smoothed versus latent state variables}')
legend('data','true latent x','true latent z',...
    'smoothed latent x','smoothed latent z'), legend boxoff
xlabel('\it{t}')
% drawnow; jFig = get(handle(gcf),'JavaFrame'); jFig.setMaximized(true);
% figname = 'example_nonlinear_ssm';
% print('-depsc2','-painters',figname)
% fixPSlinestyle([figname,'.eps'])
% saveas(gcf,figname,'fig')