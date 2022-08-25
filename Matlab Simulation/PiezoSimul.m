%% Version Info
% Created: Nov 11, 2021
% Creator: SeongHeon Hong
% Version: 1.0 (Nov 11, 2021)
%% Example Conditions
% Example Condition 1 : R=144E3, C=350E-12, s_a=60, s_r=60 (과거 DAQ만 썼을 때 조건 모사)
% Example Condition 2 : R=100E6, C=350E-12, s_a=40, s_r=5, dFde=3, T_end = 5 (병렬 저항 큰 것 사용 조건 모사)
% Example Condition 3 : R=1E18,  C=2350E-12, s_a=40, s_r=20, T_end = 10 (병렬 저항 제거(완전 절연) 현재 측정법 모사)
% 보통 돌리는데 30초 내외 소요됩니다. 룽게쿠타 4차 암시적 방법이 제일 잘 돌아갑니다.
% "%% Assume dfde profile"쪽을 바꾸면 여러 변형 상황에 대해 시뮬 가능합니다.
% 추후 dfde 및 d31 실험 데이터와 연동 예정.

%% Physical Dimensions
d31 = 35E-12;   % [C/N]     d31 value of piezo material(or equivalent value of entire sensor)
Len = 10;       % [mm]      Effective Length of the sample
A33 = 1E-4;     % [m^2]     Effective Surface Area of the Sample
A11 =1E-2*80E-6;% [m^2]     Effective Cross-sectional Area of the Sample
C = 2350E-12;   % [F]       Total Capacitance of the Sample and Measuring Circuit
R = 1E18;       % [Ohm]     Total resistance(Parallel connection of insulation and internal resistance)
                % (Parallel combination of R_samp and R_voltmeter)

%% Control Variables
s_a = 20;               % [%]       Strain Amplitude
s_r = 5;                % [mm/sec]  Elongation rate
res_time = 1;           % [sec]     Res. Time
dFde = 20;              % [N/(mm/mm)]    Can be obtained from S-S Curve
                        
%% Simulation Setting
dt = 0.01;                      % [sec] Time step
T_end = 5;                      % [sec] Time Domain
Num_method = 'Implicit RK-4';   % Select Numerical Analysis Method
%%%% 'Explicit/Implicit RK-4/RK-5/RK-6' are available.

%% Inputs
prompt = {'Insulation Resistance [Ohm]', 'Total Capacitance [F]', 'Strain Amplitude [%]' ...
    'Elongation Rate [mm/s]', 'Stiffness [N/(mm/mm)]', 'Res. time [sec]', 'Simul Time [sec]'};
dlgtitle = 'SNU-IDIM-SH Hong';
dims = [1 70];
definput = string({R, C, s_a, s_r, dFde, res_time, T_end});
answer = str2double(inputdlg(prompt, dlgtitle, dims, definput));
[R, C, s_a, s_r, dFde, res_time, T_end] = deal(answer(1), answer(2), answer(3), ...
    answer(4), answer(5), answer(6), answer(7));

dedt = s_r/Len;         % [(mm/mm)/s]   Strain Rate
dFdt = dFde .* dedt;    % [N/s]         Force Rate (Multiplication of 
                        % <Force-Strain Rate> and <Strain-Time Rate>)
                        % Ignore effect of inertia force.

%% Initialization
rf_time = (Len * s_a / 100) / s_r;
time_set = 2 * (res_time + rf_time);
t = (0 : (T_end / dt)) * dt;
dfdt = t * 0;
epsilon = t * 0;
V = t * 0;
V(1) = 0;

%% Assume dfdt profile
for i=1:size(t,2)
    if (rem(t(i), time_set) < rf_time)
        %dfdt(i) = rem(t(i), time_set)/rf_time * dFdt;
        dfdt(i) = dFdt;
        epsilon(i) = rem(t(i), time_set)/rf_time * s_a / 100;
    elseif (rem(t(i), time_set) < rf_time + res_time)
        dfdt(i) = 0;
        epsilon(i) = s_a / 100;
    elseif (rem(t(i), time_set) < 2 * rf_time + res_time)
        dfdt(i) = -dFdt;
        epsilon(i) = (1 - (rem(t(i), time_set)-rf_time - res_time) ...
            /rf_time) * s_a / 100;
    else
        dfdt(i) = 0;
    end
end

%% Initilize figure
for i=1:1  % Dummy loop. Just to contract the code.
    figure(1);
    clf;
    set(gcf, 'color', 'w', 'position', [300 100 600 800]); 
    set(gca, 'FontSize', 12, 'fontname', 'arial');
    subplot(3,1,2);
    hold on; grid on;
    ylabel("Force rate [N/s]"); xlabel("Time [sec]");
    plot(t, dfdt, 'linewidth', 1.5);
    subplot(3,1,1);
    hold on; grid on;
    ylabel("Strain [mm/mm]"); xlabel("Time [sec]");
    plot(t, epsilon, 'linewidth', 1.5);
end

%%%%%%% F/A11 = Sigma1 -> dFdt * dt /A11 = d(Sigma1) %%%%
fun = @(T, V) vpa(A33 * d31 * (dfdt(floor(T/dt)+1)/A11) / C) - V/(R*C);
%digits(32);
%% Classic Explicit RK-4th Method
if (strcmp(Num_method, 'Explicit RK-4'))
    for i = 1:size(t,2)-1
        k1 = vpa(fun(t(i), V(i)));
        k2 = vpa(fun(t(i) + 0.5 * dt, V(i) + 0.5 * dt * k1));
        k3 = vpa(fun(t(i) + 0.5 * dt, V(i) + 0.5 * dt * k2));
        k4 = vpa(fun(t(i) + 0.9999 * dt, V(i) + 0.5 * dt * k3));
        dV = vpa(1/6 * dt * (k1+2*k2+2*k3+k4));
        V(i+1) = vpa(V(i) + dV);
    end
end
%% Explicit RK-5th Method
if (strcmp(Num_method, 'Explicit RK-5'))
    for i = 1:size(t,2)-1
        k1 = fun(t(i), vpa(V(i)));
        k2 = fun(t(i) + dt/2, vpa(V(i) + dt*k1/4));
        k3 = fun(t(i) + dt/4, vpa(V(i) + dt*(k1/4 + k2/4)));
        k4 = fun(t(i) + dt/1.001, vpa(V(i) + dt*(-k2 + 2*k3)));
        k5 = fun(t(i) + dt*2/3, vpa(V(i) + dt*(k1*7/27 + k2*10/27 + k4*1/27)));
        k6 = fun(t(i) + dt*1/5, vpa(V(i) + dt*(k1*28/625 - k2/5 + k3*546/625 + k4*54/625 - k5*378/625)));
        dV = dt * (k1/24 + k4*5/48 + k5*27/56 + k6*125/336);
        V(i+1) = V(i) + dV;
    end
end
%% Implicit RK-4th Method
if (strcmp(Num_method, 'Implicit RK-4'))
    kfun = @(T, V) (A33 * d31 * (dfdt(floor(T/dt)+1)/A11) - V/R)/C;
    Aij = [1/4, 1/4-sqrt(3)/6; 1/4+sqrt(3)/6, 1/4];
    Ci = [1/2-sqrt(3)/6; 1/2+sqrt(3)/6];
    Bi = [1/2, 1/2];     
    %syms k1 k2 K11 K12 K21 K22 Ki
    %Ki = [K11; K21];
    for i = 1:size(t,2)-1
         res_Ki = (Aij * dt / (R * C) + eye(2)) \ transpose(fun(t(i) + dt * Ci, V(i)));
         V(i+1) = V(i) + dt * Bi * res_Ki;
        %s = solve(fun(t(i) + dt * Ci, V(i) + dt*Aij*Ki) == Ki ,[K11 K21]);
        %eqn1 = fun(t(i) + dt * Ci(1), V(i) + dt*(Aij(1,1)*K11 + Aij(1,2) * K21)) == K11;
        %eqn2 = fun(t(i) + dt * Ci(2), V(i) + dt*(Aij(2,1)*K11 + Aij(2,2) * K21)) == K21;
        %s = solve([eqn1, eqn2], [K11, K21]);
        %Ki = [s.K11; s.K21];
        %V(i+1) = V(i) + dt * Bi * double(Ki);        
    end    
end

%% Implicit RK-6th Method
% if (strcmp(Num_method, 'Implicit RK-6'))
%     %syms k1 k2 k3
%     %Ki = [k1; k2; k3];
%     Aij = [5/36, 2/9-sqrt(15)/15, 5/36-sqrt(15)/30; ...
%          5/36+sqrt(15)/24, 2/9, 5/36-sqrt(15)/24; ...
%          5/36+sqrt(15)/30, 2/9+sqrt(15)/15, 5/36];
%     Ci = [1/2-sqrt(15)/10; 1/2; 1/2+sqrt(15)/10];
%     Bi = [5/18, 4/9, 5/18];    
%     for i = 1:size(t,2)-1
%         res_Ki = (Aij * dt / (R * C) + eye(3)) \ transpose(kfun(t(i) + dt * Ci, V(i)));        
%         %s = solve(fun(t(i) + dt * Ci, V(i) + dt*Aij*Ki) == Ki ,Ki);
%         %res_Ki = transpose(struct2array(s));
%         V(i+1) = V(i) + dt * Bi*res_Ki;
%     end
% end
%% RK-6th Method
% for i = 1:size(t,2)-1
%     k1 = vpa(fun(t(i), V(i)));
%     k2 = vpa(fun(t(i) + dt/4, V(i) + dt*k1/4));
%     k3 = vpa(fun(t(i) + dt/4, V(i) + dt*(k1/8 + k2/8)));
%     k4 = vpa(fun(t(i) + dt/2, V(i) + dt*(-k2/2 + k3)));
%     k5 = vpa(fun(t(i) + dt*3/4, V(i) + dt*(-k1*3/8 + k4*9/8)));
%     k6 = vpa(fun(t(i) + dt/1.0001, V(i) + dt/7*(-k1*3 + k2*2 + k3*12 - k4*12 + dt*k5)));
%     dV = vpa(1/90 * dt * (7*k1 + 32*k2 + 12*k4 + 32*k5 + 7*k6));
%     V(i+1) = vpa(V(i) + dV);
% end

%% Plot
subplot(3,1,3);
hold on;grid on;
ylabel("Voltage [V]"); xlabel("Time [sec]");
plot(t, V, 'linewidth', 1.5);