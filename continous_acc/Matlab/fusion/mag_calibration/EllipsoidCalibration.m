clear all; close all; clc;

% Demonstra��o simples da utiliza��o do m�todo de ajuste de qu�drica por 
% erro quadr�tico de dist�ncia alg�brica na calibra��o de magnet�metros.
% Note que o algoritmo n�o ajusta o frame de refer�ncia, fazendo com que
% o norte magn�tico possa estar em outra posi��o (Esse ajuste � feito por
% algoritmos do tipo two-step). Para implementar esse ajuste deve existir
% uma refer�ncia externa de orienta��o para utiliza��o.

addpath('data');      % include quaternion library

%make a load of those values.
%if use this part, incomment make_new_calibration = 1;
% load('cal_data_1.mat'); make_new_calibration = 1;  %BNO was previously calibrated, but you can choose to make a new calibration
% load('cal_data_2.mat'); make_new_calibration = 0;  %BNO was previously calibrated
 load('cal_data_3_raw.mat'); make_new_calibration = 1;    %BNO NOT previously calibrated - raw data we must calibrate again


%or a load of those pairs:
% load('cal_matrix_1.mat'); load('teste_1_1.mat');make_new_calibration = 1;
% load('cal_matrix_2.mat'); load('teste_2_1.mat');make_new_calibration = 0;
% load('cal_matrix_3_raw.mat'); load('teste_3_1.mat');make_new_calibration = 1;
% load('cal_matrix_3_raw.mat'); load('teste_3_2.mat');make_new_calibration = 1;

num_pontos = length(mag_bno_gaus);
% Gr�fico dos pontos antes da calibra��o ----------------------------------
figure(1);subplot(121);rotate3d on; title('BNO')
plot3(mag_bno_gaus(1,:), mag_bno_gaus(2,:),mag_bno_gaus(3,:),'.k')
title('BNO pr� calibra��o');
figure(2);subplot(121);rotate3d on;
plot3(mag_imu_gaus(1,:), mag_imu_gaus(2,:),mag_imu_gaus(3,:),'.k')
title('MINIMU pr� calibra��o');

if( exist('Ca_imu','var') == 1)
    mag_imu_gaus_cal = mag_imu_gaus' * Ca_imu' + repmat(Cb_imu', length(mag_imu_gaus), 1);
    if make_new_calibration == 1
        mag_bno_gaus_cal = mag_bno_gaus' * Ca_bno' + repmat(Cb_bno', length(mag_bno_gaus), 1);
    else
        mag_bno_gaus_cal = mag_bno_gaus';
    end
else
    [mag_imu_gaus_cal, Ca_imu, Cb_imu] = magCalibration(mag_imu_gaus');
    if make_new_calibration == 1
        [mag_bno_gaus_cal, Ca_bno, Cb_bno] = magCalibration(mag_bno_gaus');
    else
        mag_bno_gaus_cal = mag_bno_gaus';
    end
end
mag_bno_gaus_cal = mag_bno_gaus_cal';
mag_imu_gaus_cal = mag_imu_gaus_cal';
%% Gr�ficos dos pontos ap�s a calibra��o -----------------------------------
figure(1);subplot(122);rotate3d on;
plot3(mag_bno_gaus_cal(1,:), mag_bno_gaus_cal(2,:),mag_bno_gaus_cal(3,:),'.k');
title('BNO p�s calibra��o');
figure(2);subplot(122);rotate3d on;
plot3(mag_imu_gaus_cal(1,:), mag_imu_gaus_cal(2,:),mag_imu_gaus_cal(3,:),'.k')
title('MINIMU p�s calibra��o');

figure(3);
subplot(121);
plot(mag_bno_gaus(1,:),mag_bno_gaus(2,:),'.');hold all;
plot(mag_bno_gaus(1,:),mag_bno_gaus(3,:),'.');
plot(mag_bno_gaus(3,:),mag_bno_gaus(2,:),'.');
w = linspace(0,2*pi);plot(cos(w),sin(w),'r');
title('BNO pr� calibra��o'); legend('XY','XZ','ZY');
subplot(122);
plot(mag_bno_gaus_cal(1,:),mag_bno_gaus_cal(2,:),'.');hold all;
plot(mag_bno_gaus_cal(1,:),mag_bno_gaus_cal(3,:),'.');
plot(mag_bno_gaus_cal(3,:),mag_bno_gaus_cal(2,:),'.');
w = linspace(0,2*pi);plot(cos(w),sin(w),'r');
title('BNO p�s calibra��o'); legend('XY','XZ','ZY');


figure(4);
subplot(121);
plot(mag_imu_gaus(1,:),mag_imu_gaus(2,:),'.');hold all;
plot(mag_imu_gaus(1,:),mag_imu_gaus(3,:),'.');
plot(mag_imu_gaus(3,:),mag_imu_gaus(2,:),'.');
w = linspace(0,2*pi);plot(cos(w),sin(w),'r');
title('MINIMU pre calibra��o'); legend('XY','XZ','ZY');
subplot(122);
plot(mag_imu_gaus_cal(1,:),mag_imu_gaus_cal(2,:),'.');hold all;
plot(mag_imu_gaus_cal(1,:),mag_imu_gaus_cal(3,:),'.');
plot(mag_imu_gaus_cal(3,:),mag_imu_gaus_cal(2,:),'.');
w = linspace(0,2*pi);plot(cos(w),sin(w),'r');
title('MINIMU p�s calibra��o'); legend('XY','XZ','ZY'); axis([-1.5 1.5 -1.5 1.5])

figure(5);
subplot(311);plot(t,[mag_imu_gaus(1,:); mag_bno_gaus(1,:)]'); grid on; grid on;
title('Magnet�metro');ylabel('X');legend('Minimu','BNO','Location','northwest','Orientation','horizontal')
subplot(312);plot(t,[mag_imu_gaus(2,:); mag_bno_gaus(2,:)]'); ylabel('Y'); grid on;
subplot(313);plot(t,[mag_imu_gaus(3,:); mag_bno_gaus(3,:)]'); ylabel('Z'); grid on;
xlabel('Tempo [s]')

figure(6);
subplot(311);plot(t,[mag_imu_gaus(1,:)-mean(mag_imu_gaus(1,:)); mag_bno_gaus(1,:)-mean(mag_bno_gaus(1,:))]'); 
grid on; grid on;
title('Magnet�metro removendo as m�dias');ylabel('X');legend('Minimu','BNO','Location','northwest','Orientation','horizontal')
subplot(312);plot(t,[mag_imu_gaus(2,:)-mean(mag_imu_gaus(2,:)); mag_bno_gaus(2,:)-mean(mag_bno_gaus(2,:))]'); ylabel('Y'); grid on;
subplot(313);plot(t,[mag_imu_gaus(3,:)-mean(mag_imu_gaus(3,:)); mag_bno_gaus(3,:)-mean(mag_bno_gaus(3,:))]'); ylabel('Z'); grid on;
xlabel('Tempo [s]')

figure(7);
subplot(311);plot(t,[mag_imu_gaus_cal(1,:); mag_bno_gaus_cal(1,:)]'); grid on; grid on;
title('Magnet�metro calibrado');ylabel('X');legend('Minimu','BNO','Location','northwest','Orientation','horizontal')
subplot(312);plot(t,[mag_imu_gaus_cal(2,:); mag_bno_gaus_cal(2,:)]'); ylabel('Y'); grid on;
subplot(313);plot(t,[mag_imu_gaus_cal(3,:); mag_bno_gaus_cal(3,:)]'); ylabel('Z'); grid on;
xlabel('Tempo [s]')
