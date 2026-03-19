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
Tfin = 36/a1*10; % simulation duration

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
% u0 = 0;     % fixed
% ust = 4*m;  % must be modified (saturation)
% t1 = 12/a1; % recommended

%9500
wf = 4706.68; % aprox wosc foarte apropiat de wn care ar trebui defapt
%wosc luata din step din cea trecuta
fmin = wf/2/pi/10;
fmax = wf/2/pi*2;
a_in = 1.25; %arbitrar, suf. de mare incat sa depaseasca nivelul zgomotului

%% Data acquisition (use t, u, y to perform system identification)
out = sim("Molnar_Andrei_Alexandru_circuit_electric_chirp.slx");

t = out.tout;
u = out.u;
y = out.y;

plot(t,u,t,y)
shg

%% System identification

% Ay = (-27.3785 + 45.67)/2; %primul sinus, maxim si minimul
% Au = 1.25; %intrarea setata de noi
% K = Ay/Au ;
% Ayr = (-22.835 + 49.887)/2; %maximul si minimul
% Aur = 1.25;
% Mr = Ayr/Aur;
% wr = pi/(0.0162674 - 0.0159289)
% r = roots([4*Mr^2 0 -4*Mr^2 0 K^2])
% zeta = 0.3628
% wn = wr / (sqrt(1-2*zeta^2))

Ay = ( 18.2515 - 9.08617)/2; %primul sinus, maxim si minimul
%Ay = ( 20.5634 - 10.5208)/2;
Au = 1.25; %intrarea setata de noi
K = Ay/Au ;


Ayr = (-8.60795 + 22.1177)/2; %maximul si minimul
%Ayr = (-8.4884 + 22.2372)/2;
Aur = 1.25;
Mr = Ayr/Aur;

wr = pi/(0.0418801 - 0.0410682);
r = roots([4*Mr^2 0 -4*Mr^2 0 K^2])
zeta = 0.3858
wn = wr / (sqrt(1-2*zeta^2))

%% Validare

%K = 3.675
%wn = 4785.71678109009

% zeta = 0.4061
% zeta = 0.38
A = [0,1;-wn^2,-2*zeta*wn];
B = [0;K*wn^2];
C = [1,0];
D = 0;
sys = ss(A,B,C,D);
y_sim2 = lsim(sys,u,t,[y(1),-10000]);

%figure
%y = sgolayfilt(y,21,201);

figure
plot(t,u,t,y,t,y_sim2)

J = 1/sqrt(length(t))*norm(y-y_sim2)
eMPN = norm(y-y_sim2)/norm(y-mean(y))*100