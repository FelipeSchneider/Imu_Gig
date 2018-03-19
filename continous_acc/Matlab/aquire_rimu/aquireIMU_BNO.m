clear all; clc; 
close all;
fclose(instrfind);

%% Defini��o dos parametros iniciais do ensaio
BLUETOOTH = 0;          %se for usar bluetooth sete este define, se for usar 
                        %conversor serial USB configure em 0
                        
time_sample = 10;       %n�mero de segundos a se coletar
fs = 100;              %Frequ�ncia de amostragem (depende do micro)
n_amostras = time_sample*fs;

t = 0:1/fs:time_sample; %define o vetor de tempo
t(end) = [];            %elimina a ultima posi��o do vetor tempo

COM_imu = 16;            %Numero da porta COM
COM_imu_baud = 230400; %Baud rate
COM_header_1 = 83;       %Header de inicio da comunica��o
COM_header_2 = 172;      %Header de inicio da comunica��o
ACTION = 164;            %a��o: ler LSM+LIS e o raw data do BNO

G_MAX_IMU = 4;
G_MAX_BNO = 8;
DPS_MAX_IMU = 1000;
DPS_MAX_BNO = 1000;
GAUSS_MAX = 4;
MICRO_TESLA_MAX = 40;

%% dados magn�ticos de vit�ria
%https://www.ngdc.noaa.gov/geomag-web/#igrfwmm
% Model Used:	WMM2015	More information
% Latitude:	20� 19' 59" S
% Longitude:	40� 24' 50" W
% Elevation:	0.0 km Mean Sea Level

% Date 2017-08-24	
% ( + E  | - W ) Declination -23� 44' 36"	
% ( + D  | - U ) Inclination -39� 55' 15"	
% Horizontal Intensity 18136.9 nT	
% (+ N  | - S) North Comp 16601.8 nT	
% (+ E  | - W) East Comp -7302.7 nT	
% (+ D  | - U) Vertical Comp -15176.0 nT	
% Total Field 23648.6 nT

%% Inicializa��o das portas e vari�veis
COM_imu_name = sprintf('COM%d',COM_imu);
%pattern: first line: x, second line y, third line z
giro_imu = zeros(3,n_amostras); %prealoca��o para melhora da performance
acc_imu = zeros(3,n_amostras); 
mag_imu = zeros(3,n_amostras); 

giro_bno = zeros(3,n_amostras); %prealoca��o para melhora da performance
acc_bno = zeros(3,n_amostras); 
mag_bno = zeros(3,n_amostras); 

if(BLUETOOTH == 0)
    disp('iniciando Conversor Serial USB')
    s_imu = serial(COM_imu_name,'BaudRate',COM_imu_baud,'DataBits',8);
else
    disp('iniciando Bluetooth')
    s_imu = Bluetooth('RIMU',1);
    disp('Conectando')
end
s_imu.InputBufferSize = n_amostras*20;
fopen(s_imu);
flushinput(s_imu);
pause(1);
%% Coleta de valores
cont_exit = 0; bytes = 0;
press = 0;
disp('iniciando a coleta')   

time_sample_hi = floor(time_sample/255);
time_sample_lo = time_sample-time_sample_hi*255;

msg = [COM_header_1 COM_header_2 ACTION time_sample_hi time_sample_lo];
fwrite(s_imu,msg,'uint8');
disp('Mensagem inicial enviada')

for j=1:n_amostras
        if(mod(j,fs)==0)                    %print o segundo atual
            fprintf('Segundo %d \r',j/fs)
        end
        while (bytes < 36)
                 bytes = s_imu.BytesAvailable;
        end
        giro_imu(:,j) = fread(s_imu,3,'int16');
        acc_imu(:,j) = fread(s_imu,3,'int16');
        mag_imu(:,j) = fread(s_imu,3,'int16');
        
        acc_bno(:,j) = fread(s_imu,3,'int16');
        mag_bno(:,j) = fread(s_imu,3,'int16');
        giro_bno(:,j) = fread(s_imu,3,'int16');
end

flushinput(s_imu);
fclose(instrfind);

%% P�s processing
%minimu
giro_imu_dps = double(giro_imu)/(2^15)*DPS_MAX_IMU;
acc_imu_g = double(acc_imu)/(2^15)*G_MAX_IMU;
mag_imu_gaus = double(mag_imu)/(2^15)*MICRO_TESLA_MAX;

%bno055
giro_bno_dps = double(giro_bno)/(2^15)*DPS_MAX_BNO;
acc_bno_g = double(acc_bno)/(2^13)*G_MAX_BNO;
mag_bno_gaus(1,:) = double(mag_bno(1,:))/(2^14)*MICRO_TESLA_MAX;
mag_bno_gaus(2,:) = double(mag_bno(2,:))/(2^14)*MICRO_TESLA_MAX;
mag_bno_gaus(3,:) = double(mag_bno(3,:))/(2^14)*MICRO_TESLA_MAX;

% for i=1:length(mag_bno_gaus)
%     total_field(i) = norm(mag_imu_gaus(:,i));
% end
%% Plots
figure;
subplot(311);plot(t,[giro_imu_dps(1,:); giro_bno_dps(1,:)]'); grid on;
title('Girosc�pio');ylabel('X [dps]');legend('Minimu','BNO','Location','northwest','Orientation','horizontal')
subplot(312);plot(t,[giro_imu_dps(2,:); giro_bno_dps(2,:)]'); ylabel('Y [dps]'); grid on;
subplot(313);plot(t,[giro_imu_dps(3,:); giro_bno_dps(3,:)]'); ylabel('Z [dps]'); grid on;
xlabel('Tempo [s]')

figure;
subplot(311);plot(t,[acc_imu_g(1,:); acc_bno_g(1,:)]'); grid on;
title('Aceler�metro');ylabel('X [g]');legend('Minimu','BNO','Location','northwest','Orientation','horizontal')
subplot(312);plot(t,[acc_imu_g(2,:); acc_bno_g(2,:)]'); ylabel('Y [g]'); grid on;
subplot(313);plot(t,[acc_imu_g(3,:); acc_bno_g(3,:)]'); ylabel('Z [g]'); grid on;
xlabel('Tempo [s]')

figure;
subplot(311);plot(t,[mag_imu_gaus(1,:); mag_bno_gaus(1,:)]'); grid on; grid on;
title('Magnet�metro');ylabel('X');legend('Minimu','BNO','Location','northwest','Orientation','horizontal')
subplot(312);plot(t,[mag_imu_gaus(2,:); mag_bno_gaus(2,:)]'); ylabel('Y'); grid on;
subplot(313);plot(t,[mag_imu_gaus(3,:); mag_bno_gaus(3,:)]'); ylabel('Z'); grid on;
xlabel('Tempo [s]')

figure;
subplot(121);
plot(mag_imu_gaus(1,:),mag_imu_gaus(2,:),'.');hold all;
plot(mag_imu_gaus(1,:),mag_imu_gaus(3,:),'.');
plot(mag_imu_gaus(3,:),mag_imu_gaus(2,:),'.');
w = linspace(0,2*pi);plot(cos(w),sin(w),'r');
title('Elipsoide Minimu'); legend('XY','XZ','ZY');
hs(2) = subplot(122);
scatter3(hs(2),mag_imu_gaus(1,:),mag_imu_gaus(2,:),mag_imu_gaus(3,:),'*')

figure;
subplot(121);
plot(mag_bno_gaus(1,:),mag_bno_gaus(2,:),'.');hold all;
plot(mag_bno_gaus(1,:),mag_bno_gaus(3,:),'.');
plot(mag_bno_gaus(3,:),mag_bno_gaus(2,:),'.');
w = linspace(0,2*pi);plot(cos(w),sin(w),'r');
title('Elipsoide BNO'); legend('XY','XZ','ZY');
hs(2) = subplot(122);
scatter3(hs(2),mag_bno_gaus(1,:),mag_bno_gaus(2,:),mag_bno_gaus(3,:),'*')
