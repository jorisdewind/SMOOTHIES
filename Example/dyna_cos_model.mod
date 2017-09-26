%Declaring variables
var xx yy zz;                      %Variables
varexo epsy etax etaz;             %Disturbances

%Setting parameter values
parameters rhox mux rhoz muz hy qx qz;
load parameters;
set_param_value('rhox',rhox);
set_param_value('mux' ,mux);
set_param_value('rhoz',rhoz);
set_param_value('muz' ,muz);
set_param_value('hy'  ,hy);
set_param_value('qx'  ,qx);
set_param_value('qz'  ,qz);

%Model equations
model;
yy - cos( xx^2 + epsy ) * exp( zz ) = 0;            %Measurement equation
xx - rhox * xx(-1) - (1 - rhox) * mux - etax = 0;   %State equation for x
zz - rhoz * zz(-1) - (1 - rhoz) * muz - etaz = 0;   %State equation for z
end;

%Setting standard deviations of disturbances
shocks;
var epsy; stderr hy;
var etax; stderr qx;
var etaz; stderr qz;
end;