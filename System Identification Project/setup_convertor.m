%%
% Nume si prenume: Molnar Andrei Alexandru
%

clearvars
clc

%% Magic numbers (replace with received numbers)
m = 6;
n = 12;

%% Process data and experiment setup (fixed, do not modify)
u_star = 0.15+n*0.045; % trapeze + PRBS amplitudes
delta = 0.02;
delta_spab = 0.015;

E = 12;  % converter source voltage

umin = 0; umax = 0.98; % input saturation
assert(u_star < umax-0.1)
ymin = 0; ymax = 1/(1-u_star)*E*2; % output saturation

% circuit components + parasitic terms
R = 15;
rL = 10e-3;
rC = 0.2;
rDS1 = 0.01;
rDS2 = 0.01;
Cv = 600e-6/3*m;
Lv = 40e-3*3/m;

% (iL0,uC0)
rng(m+10*n)
x0_slx = [(-1)^(n+1)*E/R,E/3/(1-u_star)];

Ts = 1e-5*(1+2*(u_star-0.15)/u_star); % fundamental step size
Ts = round(Ts*1e6)/1e6;

% input white noise power and sampling time
whtn_pow_in = 1e-11*(Ts*1e4)/2; 
whtn_Ts_in = Ts*2;
whtn_seed_in = 23341+m+2*n;
q_in = (umax-umin)/pow2(11); % input quantizer (DAC)

% output white noise power and sampling time
whtn_pow_out = 1e-7*E*(Ts*1e4/50)*(1+(50*u_star)*(u_star-0.15))/3; 
whtn_Ts_out = Ts*2;
whtn_seed_out = 23342-m-2*n;
q_out = (ymax-ymin)/pow2(11); % output quantizer (ADC)

meas_rep = 13+ceil(n/2); % data acquisition hardware sampling limitation

%% Input setup (can be changed/replaced/deleted)
% Tfin = 2; % simulation duration
% t0 = Tfin/4;
% t1 = Tfin/2;

t1 = 0.3;
tr = 0.03*2 ; % timp de urcare + *2 sau *3 datorita oscilatiilor puternice
N = 6; % la alegere nr de biti SPAB
p = round(tr/N/Ts);
DeltaT = p*(2^N-1)*Ts*5 ;  % perioada SPAB, merge mai mult decat valoarea asta, dar nu mai putin

[input_LUT_dSPACE,Tfin] = generate_input_signal(Ts,t1,DeltaT,N,p,u_star,delta,delta_spab);
%LUT - look up table =tabel auxiliar, lista de perechi pentru u si t



%% Data acquisition (use t, u, y to perform system identification)
out = sim("convertor_R2022b.slx");

t = out.tout;
u = out.u;
y = out.y;

subplot(211)
plot(t,u)
subplot(212)
plot(t,y)

%% System identification
% neliniar, pentru tensiune mai mare, nu are aceeassi fdt
% p cat de mult sa dureze , t1 cat ii ia pana sa nu mai osclieze la
% inceput, dT cat sa dureze SPAB
%cea mai lunga perioada din SPAB trebuie sa fie mai lunga decat timpul de
%urcare p*N*Ts

%MEREU PRIMA DATA SEPARAM DATELE

i1 = 67717;
i2 = 224011;
i3 = 272689;
i4 = 429458;

Nr = 23;

t_id = t(i1:Nr:i2);
u_id = u(i1:Nr:i2);
%t_id = t(i1:i2);
%u_id = u(i1:i2);
u_id = sgolayfilt(u_id,16,21);
%u_id = medfilt1(u_id,7)

u_id = u_id - mean(u_id);
%u_id = detrend(u_id);

y_id = y(i1:Nr:i2);
%y_id = y(i1:i2);
y_id = sgolayfilt(y_id,16,21);
%y_id = medfilt1(y_id,7)

y_id = y_id - mean(y_id);
%y_id = detrend(y_id);

t_vd = t(i3:Nr:i4);
u_vd = u(i3:Nr:i4);
% t_vd = t(i3:i4);
% u_vd = u(i3:i4);
u_vd = sgolayfilt(u_vd,16,21);
%u_vd = medfilt1(u_vd,7);

u_vd = u_vd - mean(u_vd);
%u_vd = detrend(u_vd);


y_vd = y(i3:Nr:i4);
%y_vd = y(i3:i4);
y_vd = sgolayfilt(y_vd,16,21);
%y_vd = medfilt1(y_vd,7);

y_vd = y_vd - mean(y_vd);
%y_vd = detrend(y_vd);


figure
subplot(221)
plot(t_id,u_id)
subplot(223)
plot(t_id,y_id)
subplot(222)
plot(t_vd,u_vd)
subplot(224)
plot(t_vd,y_vd)

%y_id = sgolayfilt(y_id,11,101)
%y_vd = sgolayfilt(y_vd,51,401)

dat_id = iddata(y_id, u_id, t_id(2)-t_id(1));
dat_vd = iddata(y_vd, u_vd, t_vd(2)-t_vd(1));

%dat_id = iddata(y_id, u_id, Ts_id);
%dat_vd = iddata(y_vd, u_vd, Ts_id);


%% MODEL ARX

model_arx = arx(dat_id,[2 2 1]) % ideal
%minim doi poli, minim un zero, ca sa aiba pornirea aia in jos

figure
resid(model_arx,dat_vd)
% vrem ca primii tacti din resid : Number of free coefficients: 4 sa fie in banda
figure
compare(model_arx,dat_vd)

%% MODEL ARMAX

model_armax = armax(dat_id,[2 2 16 2])

figure
resid(model_armax,dat_vd)
figure
compare(model_armax,dat_vd)

%% MODEL OE

model_oe = oe(dat_id,[2 2 0])

figure
resid(model_oe,dat_vd)
figure
compare(model_oe,dat_vd)

%uita te in pdf sa cauti in ultimele liniute de rafinare a datelor

%% MODEL BJ

model_bj = bj(dat_id,[2 9 2 2 2])

model_bj = pem(dat_id,model_bj);

pole(model_bj)
zero(model_bj)
figure
resid(model_bj,dat_vd)
figure
compare(model_bj,dat_vd)

%% MODEL IV4

model_iv4 = iv4(dat_id,[2 2 1])

model_iv4 = pem(dat_id,model_iv4);
figure
resid(model_iv4,dat_vd)
figure
compare(model_iv4,dat_vd)

%% n4sid

model_n4sid = n4sid(dat_id,1:15)

model_n4sid1 = pem(dat_id,model_n4sid);
figure
resid(model_n4sid1,dat_vd)
figure
compare(model_n4sid1,dat_vd)

%% ssest

model_ssest = ssest(dat_id,1:15)

model_ssest = pem(dat_id,model_ssest);
figure
resid(model_ssest,dat_vd)
figure
compare(model_ssest,dat_vd)

zpk(model_ssest)

%trebuie sa indeplineasca cerintele din pdf ul respectiv, pdf proiect 5

%criteriu care e cel mai bun + pentru cele neparametrice

%% impulseest

model_impulseest = impulseest(dat_id,1:15)
figure
resid(model_impulseest,dat_vd)
figure
compare(model_impulseest,dat_vd)

%% ssest

model_ssregest = ssregest(dat_id,1:15)
figure
resid(model_ssregest,dat_vd)
figure
compare(model_ssregest,dat_vd)