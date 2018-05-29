function [q_out] = Kalman_response(X,acc_data, gyro_data, mag_data, bw, fn, mn, fs)
%Kalman_response returns the response of the kalman filter for each group
%of parameters X
%   fn  - Gravity vector in navigation frame [3x1]
%   mn  - Magetic field vector in navigation frame [3x1]
%   fs  - sampling frequency
 c = size(X,2);
 q_out = zeros(length(acc_data),4,c);   %first position the time stamp
                                        %second position define the quaternion
                                        %last position define the particle
%R is the measurement noise covariance matrix
%P is the error covariance matrix
warning('off', 'MATLAB:illConditionedMatrix');

for j=1:c
    j
    R(1:3,1:3)=diag([X(1,j), X(1,j), X(1,j)]);        %Initial Covariance matrix
    R(4:6,4:6)=diag([X(2,j), X(2,j), X(2,j)]);
    P(1:3,1:3)=diag([X(3,j), X(3,j), X(3,j)]);        %Initial Covariance matrix
    P(4:6,4:6)=diag([X(4,j), X(4,j), X(4,j)]);
    [q, ~, ~] = Gyro_lib_quat(P, bw, gyro_data*(pi/180*(1/fs)), X(5,j), X(6,j),...
    acc_data, mag_data, fn, mn, 1/fs, R);  
    
    %correcting the bad scalar matrices 
    q(isnan(q(:,1)),1) = 1; %replace NaN by unit vector
    q(isnan(q(:,2)),2:4) = 0;
    if(norm(q(9,:)) == 0) % if this position is all zero
        q(9,:) = [1 0 0 0];
    end
    
    %correct the initial position
    q_zero = avg_quaternion_markley(q(380:480,:));
    q = quatmultiply(quatconj(q_zero'),q);
    q_out(:,:,j) = q;
end


teste = q;
teste(isnan(teste(:,1)),1) = 1;
teste(isnan(teste(:,2)),2:4) = 0;

warning('on', 'MATLAB:illConditionedMatrix');