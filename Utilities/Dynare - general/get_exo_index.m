%%  Get index of exogenous variable Dynare
%
%       Joris de Wind (February 2014)
%==========================================================================

function index = get_exo_index(name)

global M_

for i = 1:size(M_.exo_names,1)
    if strcmp(strtrim(M_.exo_names(i,:)),name)
        index = i;
        return
    end
end

end