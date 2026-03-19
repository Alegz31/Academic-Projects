function [input_LUT_dSPACE,Tfin] = generate_input_signal(...
    Ts,t1,DeltaT,N,p,u_star,delta,delta_prbs)
% Configure and generate (time,input) pair for identification experiment,
% simulating actual hardware from practice (such as dSPACE).

assert(N>=2 & N<=11)

% define time moments for switching
t2 = t1+DeltaT/2;
no_prbs_t = DeltaT/10;
t3 = t2+DeltaT+2*no_prbs_t;
t4 = t3+DeltaT/2;
t5 = t4+DeltaT+2*no_prbs_t;
t6 = t5+DeltaT/2;

% trapeze levels
u0 = u_star-delta;
u_st = u_star+delta;

num_points_total = round(t6/Ts);

t = 0:Ts:(num_points_total)*Ts;

u_trapz = ...
    u0.*(t < t1) + ...
    (u0 + (u_st - u0).*(t - t1)/(t2 - t1)).*(t >= t1 & t <= t2) + ...
    u_st.*(t > t2 & t < t3) + ...
    (u_st + (u0 - u_st).*(t - t3)/(t4 - t3)).*(t >= t3 & t <= t4) + ...
    u0.*(t > t4 & t < t5) + ...
    (u0 + (u_st - u0).*(t - t5)/(t6 - t5)).*(t >= t5 & t <= t6) + ...
    u_st.*(t > t6);

num_points_level = sum((t>=t2+no_prbs_t & t<=t3-no_prbs_t))+10;

u_PRBS = PRBS(N,num_points_level,p);

% ensure correct assignment dimensions
L_assignment1 = length(u_trapz(t>=t2+no_prbs_t & t<=t3-no_prbs_t));
u_trapz(t>=t2+no_prbs_t & t<=t3-no_prbs_t) = ...
    u_trapz(t>=t2+no_prbs_t & t<=t3-no_prbs_t) + ...
    (2*delta_prbs*u_PRBS(1:L_assignment1)'-delta_prbs);

% ensure correct assignment dimensions
L_assignment2 = length(u_trapz(t>=t4+no_prbs_t & t<=t5-no_prbs_t));
u_trapz(t>=t4+no_prbs_t & t<=t5-no_prbs_t) = ...
    u_trapz(t>=t4+no_prbs_t & t<=t5-no_prbs_t) + ...
    (2*delta_prbs*fliplr(u_PRBS(1:L_assignment2)')-delta_prbs);

u_dSPACE = u_trapz;
Tfin = t(end);

t_dSPACE = (0:length(u_dSPACE)-1)*Ts;
t_dSPACE = t_dSPACE(:);
u_dSPACE = u_dSPACE(:);
input_LUT_dSPACE = [t_dSPACE,u_dSPACE];

end

function [u] = PRBS(N,L,p)

    % optimal bit configuration
    [bi,bj] = find_opt_config(N);

    % register initialization
    reg = ones(N,1);

    u = [];
    
    while length(u) < L
        % insert in input signal the current value from the register
        u = [u; reg(end)*ones(p,1)];
        new_bit = xor(reg(bi),reg(bj));
        % update new bit in register
        reg = [new_bit; reg(1:end-1)];
    end

    % keep first L items
    u = u(1:L);

end


function [bi,bj] = find_opt_config(N)
    bi_v = [1 1 3 3 5 4 3 5 7 9]; 
    bj_v = [2 3 4 5 6 7 8 9 10 11];

    bi = bi_v(N-1);
    bj = bj_v(N-1);
end