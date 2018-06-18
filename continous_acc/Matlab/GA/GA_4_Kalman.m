addpath('C:\Users\felip\Dropbox\Mestrado\Dissertação\Coletas Jiga\Teste_giro_filt')  %just to be able to load previously jig measurements
addpath(genpath('C:\Users\felip\Documents\Arquivos dissertação\Testes dissertação\data colection'))
addpath(genpath('..\fusion'));
addpath('..\jig');
addpath('..\');
% addpath('..\aquire_rimu');
load random2
clearvars -except acc_bno_g acc_imu_g com_data description fs giro_bno_dps giro_imu_dps ...
    jig_const mag_bno_gaus mag_imu_gaus Q real_base_angle real_top_angle t...
    t_angles t_imu t_rec
clc; close all;
%% Genetic Algorithms parameters
plot_figures = 1;
n_particles = 15;
nIterations = 15;
alpha = 0.25;
r_mutation = 0.05;
% Xmin = [10e-3   10e-3   10e-4   10e-6   10e-6   10e-6]; %limits of search
% Xmax = [1       1       10e-1   10e-1   10e-2   10e-4];

Xmin = [5e-2   5e-2   5e-3   5e-5   5e-5   5e-8]/100; %limits of search
Xmax = [5e-1   5e-1   5e-2   5e-4   5e-4   5e-7]*5;
%X(1) -> Three values of superior diag. of R -> R(1,1);R(2,2);R(3,3). measurement noise covariance matrix
%X(2) -> Three values of inferior diag. of R -> R(4,4);R(5,5);R(6,6). measurement noise covariance matrix
%X(3) -> Three values of superior diag. of P -> P(1,1);P(2,2);P(3,3). error covariance matrix
%X(4) -> Three values of inferior diag. of P -> P(4,4);P(5,5);P(6,6). error covariance matrix
%X(5) -> gyro error noise
%X(6) -> gyro bias noise
%original values [1e-1 1e-1 1e-2 1e-4 1e-4 1e-7]
%% Data that must be pre entered
acc_data = acc_bno_g;
giro_data = giro_bno_dps;
mag_data = mag_bno_gaus;

% acc_data = acc_imu_g;
% giro_data = giro_imu_dps;
% mag_data = mag_bno_gaus;

%Kalman constants
fs = 100;                                   %sampling rate
bw = mean(giro_data(:,100:400),2);          %gyro bias
fn = mean(acc_data(:,100:400),2);           %gravity in the sensor frame
mn = mean(mag_data(:,100:400),2);           %magnetic field in the sensor frame

%magnetometer calibration
[mag_imu_gaus_cal, Ca_imu, Cb_imu] = magCalibration(mag_imu_gaus');
mag_imu_gaus_cal = mag_imu_gaus_cal';

%% Compensating the jig time and 
t_rec(1) = [];                  %the first position is a zero, used only for prealocation
t_expect = com_data(1,:);       %extracting the expect time for each command
t_expect(end+1) = t(end);       %filling with the end of all comands here
t = t-t_rec(1);

comp_factor = t_rec(end)/t_expect(end);
%comp_factor = 123.5/123.0383;    %took from graph FUSION4
%comp_factor = 56.7/56.8678;     %took from graph FUSION5
%comp_factor = 254.13/253.07818;                   %FUSION 6
t_jig_comp = t*comp_factor;

%just to plot the marks on the graph
b_angle_expect = com_data(2,:); b_angle_expect(end+1) = real_base_angle(end);
t_angle_expect = com_data(3,:); t_angle_expect(end+1) = real_top_angle(end);

%wrap the aligned angles around -180 and 180 degrees
b_angle = wrapTo180(real_base_angle); b_angle_expect = wrapTo180(b_angle_expect);
t_angle = wrapTo180(real_top_angle);  t_angle_expect = wrapTo180(t_angle_expect);

%match the imu and jig times
[t_match, base_match, top_match] = matchJigIMU(t_jig_comp, t_imu, b_angle, t_angle);
q_jig = zeros(length(t_match),4);
for i=1:length(top_match)
    q_jig(i,:) = angle2quat(base_match(i)*pi/180, 0, -top_match(i)*pi/180,'ZXY');
end

%% GA CODE
n=0;
n_mutations = round(r_mutation*n_particles);    %number of mutations
n_mutations = max(1,n_mutations);               %minimum number of mutations
n_parameters = length(Xmin);                    %number of parameters for each particle

% initialization using uniform probability distribution for each particle
X = zeros(n_parameters,n_particles); 
Pbest = zeros(n_parameters,n_particles);
for k = 1:n_particles
    for j=1:n_parameters
        X(j,k) = Xmin(j) + (Xmax(j)-Xmin(j))*rand(1);
    end
end

%[ left_particles, right_particles ] = plotParticles(X, Xmin, Xmax, plot_figures);

%% First GA iteration
%function value calculation for each particle
fprintf('GA particle initialization \n')
[q_out, X] = Kalman_response(X, acc_data, giro_data, mag_data, bw, fn, mn, fs, Xmin, Xmax);
[fit] = Kalman_fit(q_out,q_jig);

%find the best particle
[fGbest,id_best] = min(fit);
Gbest = X(:,id_best);
[ HP_particles ] = plotParticles(X, Gbest, Xmin, Xmax, plot_figures);
[ HP_estimation ] = plotEstimation(t_imu, q_out, q_out(:,:,id_best), q_jig, plot_figures);
%% Second to last GA iteration
for n=1:nIterations
    fprintf('GA iteration number %d \r',n)
    [X,fit] = updateX(X,alpha, q_jig, Xmin, Xmax, acc_data, giro_data, mag_data, bw, fn, mn, fs);
    [X,Gbest,fGbest,id_best] = FindBest(X, fit, fGbest, Gbest);

    fprintf('RMS best fit: %f \r',fGbest);
    [X] = mutation(X, n_mutations, id_best, Xmin, Xmax);
    [ ~ ] = plotParticles(X, Gbest, Xmin, Xmax, plot_figures, n, HP_particles);
    [ ~ ] = plotEstimation(t_imu, q_out, q_out(:,:,id_best), q_jig, plot_figures, n, HP_estimation);
end