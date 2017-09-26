%%  Get index of endogenous variable Dynare
%
%       Joris de Wind (February 2014)
%==========================================================================

function index = get_endo_index(name)

global M_

for i = 1:size(M_.endo_names,1)
    if strcmp(strtrim(M_.endo_names(i,:)),name)
        index = i;
        return
    end
end

end