%%
% Nume si prenume: Molnar Andrei Alexandru
%

clearvars
clc

%% Magic numbers (replace with received numbers)
m = 6; 
n = 12; 

%% Process data (fixed, do not modify)
a1 = 2*(0.15+(m+n/20)/30)*(1000+n*300);
a2 = (1000+n*300);
b0 = (2.2+m+n)/5.5;

rng(m+10*n)
x0_slx = [(-1)^n*(-m/10-rand(1)*m/5); (-1)^m*(n/20+rand(1)*n/100)];

%% Experiment setup (fixed, do not modify)
Ts = 20/a1/1e4; % fundamental step size
Tfin = 36/a1; % simulation duration

gain = 15;
umin = -gain; umax = gain; % input saturation
ymin = -b0*gain/1.8; ymax = b0*gain/1.8; % output saturation

whtn_pow_in = 1e-9*5*(((m-1)*5+n)/5)/2; % input white noise power and sampling time
whtn_Ts_in = Ts*3;
whtn_seed_in = 23341+m+2*n;
q_in = (umax-umin)/pow2(9); % input quantizer (DAC)

whtn_pow_out = 1e-8*5*(((m-1)*8+n)/5)/2; % output white noise power and sampling time
whtn_Ts_out = Ts*5;
whtn_seed_out = 23342-m-2*n;
q_out = (ymax-ymin)/pow2(9); % output quantizer (ADC)

u_op_region = -(m+n/5)/2; % operating point

%% Input setup (can be changed/replaced/deleted)
u0 = 0;     % fixed
ust = 6;  % must be modified (saturation)
t1 = 12/a1; % recommended 

%% Data acquisition (use t, u, y to perform system identification)
out = sim("MOLNAR_Andrei_Alexandru_circuit_electric_regresie.slx");

t = out.tout;
u = out.u;
y = out.y;

plot(t,u,t,y)
shg
hold on  


%% System identification

i1 = 5205;
i2 = 5791;
i3 = 11165;
i4 = 11760;

indici_selectati = [i1, i2, i3, i4];
plot(t(indici_selectati), y(indici_selectati), 'y*', 'MarkerSize', 10, 'LineWidth', 2);

u_0 = mean (u(i1:i2));
u_st = mean (u(i3:i4));

y_0 = mean (y(i1:i2));
y_st = mean (y(i3:i4));

k = (y_st - y_0)/(u_st - u_0);


%% Partea reala a poliilor

i5 = 5995;
i6 = 12000;

t_aux = t(i5:i6);
y_aux = abs(y(i5:i6) - y_st);

figure
plot(t_aux, y_aux)
%%
%i7 = 12;
%i8 = 1291; 
%i9 = 2556;
i7 = 28;
i8 = 1290;
i9 = 2592;


t_reg = t_aux([i7 i8 i9]);
y_reg = log (y_aux([i7 i8 i9]));

figure
plot(t_reg,y_reg)

%%
A_reg = [sum(t_reg.^2), sum(t_reg) ; sum(t_reg) , length(t_reg)] ;
B_reg = [ sum(y_reg.*t_reg) ; sum(y_reg)];

theta = inv(A_reg)*B_reg;

Re = theta(1);

%% Partea imaginara

i10 = 6000;
i11 = 7225;

Tosc = 2 * (t(i11)-t(i10));
Im = 2 * pi / Tosc;

%% zeta wn

wn = sqrt(Re^2+Im^2);

zeta = - Re / wn;

%% Validarea sistemului

%wn = 4706.68012267161;

A = [0,1;-wn^2,-2*zeta*wn];
B = [0;k*wn^2];
C = [1,0];
D = 0;
sys = ss(A,B,C,D);
y_sim2 = lsim(sys,u,t,[y(1),0]);

figure
plot(t,u,t,y,t,y_sim2)

J = 1/sqrt(length(t))*norm(y-y_sim2)
eMPN = norm(y-y_sim2)/norm(y-mean(y))*100