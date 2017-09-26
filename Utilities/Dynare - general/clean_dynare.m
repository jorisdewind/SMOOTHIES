function clean_dynare(name_mod_file,name_directory_results,varargin)

% This Matlab function re-organizes all the files created by Dynare.
%
%       !! Works on Mac OS as well as Windows !!
%
%   Input argument 1:   name of mod file, without filename extension
%   Input argument 2:   name of sub-directory for results and backup
%   Input argument 3:   logical indicating whether to delete results
%
%   Joris de Wind (April 2015)
%--------------------------------------------------------------------------

%Temporarily rename two main files
    copyfile([name_mod_file,'.mod']          ,['temp_',name_mod_file,'.mod'])
try copyfile([name_mod_file,'_steadystate.m'],['temp_',name_mod_file,'_steadystate.m']), end %#ok<TRYNC>

%Move files to sub-directory (including main mod file and steady-state m file)
movefile([name_mod_file,'*'],name_directory_results)

%Restore names two main files
    movefile(['temp_',name_mod_file,'.mod']          ,[name_mod_file,'.mod'])
try movefile(['temp_',name_mod_file,'_steadystate.m'],[name_mod_file,'_steadystate.m']), end %#ok<TRYNC>

%If requested, delete all the files created by Dynare
if nargin == 3 && islogical(varargin{1}) && varargin{1},
    rmdir(name_directory_results,'s')
end