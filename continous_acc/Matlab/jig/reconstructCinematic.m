function [ t, base_angle, top_angle, start_com ] = reconstructCinematic( com_vector, jig_const)
%[ t, base_angle, top_angle ] = reconstructCinematic( com_vector, dt )
% This function reconstructs the jig cinematics and its in a determinated 
%time acording to the set of commands that are send to the microcontroller
%   com_vector      The set of commands that will be send to the
%                   microcontroller. This vector is usually generated by
%                   the createComVector function and follows the protocol
%                   describe there
%   jig_const       The constants structure related to the jig
%   dt              time step between each position sample
%   t               output the time vector
%   base_angle      output the base angle for each time position
%   top_angle       output the top angle for each time position
%   start_com       line matrix that return the start time of each command
%                   in the first line, in the second and third line it return the
%                   angle that each command have started for the base and
%                   top motors
%equations for the Uniformly Varied Moviment (still linear)
%   V = Vo + a*t;
%   S = So + Vo*t + (1/2)*a*t^2
%   V^2 = Vo^2 + 2*a*DS;
dt = 1/jig_const.acc_mod;
cnt = jig_const;

t = -dt;              %the values that will be returned
base_angle = 0;
top_angle = 0;
%start_com = zeros(3,ceil(length(com_vector)-4/4)); % useful to forecast where a new command starts
start_com = 0;
for i=1:4:length(com_vector)-4 %-4 to not consider the end of commands
    %B_ means a variable relative to the base motor
    %T_ a variable relative to top motor
    % _w is related to angle displacement
    B_speed = com_vector(i);
    B_st = com_vector(i+1);        %programmed base steps
    T_speed = com_vector(i+2);
    T_st = com_vector(i+3);        %programmed top steps
    B_w = 0;                       %angle moved in a single command for the base motor
    T_w = 0;                       %angle moved in a single command for the top motor
    
    start_com(1,ceil(i/4)) = t(end)+dt;
    start_com(2,ceil(i/4)) = base_angle(end);
    start_com(3,ceil(i/4)) = top_angle(end);
    
    if(abs(B_speed) >= cnt.min_w)   %if the base motor will move at this command
        B_step_to_cruse = round((B_speed^2 - cnt.min_w^2)/(2*cnt.acc_mod*cnt.d_theta)); %   V^2 = Vo^2 + 2*a*DS;
        B_step_breaking = round((B_speed^2 - cnt.min_w^2)/(2*cnt.breaking_mod*cnt.d_theta)); %   V^2 = Vo^2 + 2*a*DS; DS = n_steps*d_theta
        
        %calculating the real cruse speed, number of steps to cruse... for BASE
        %motor
        if(B_st >= (B_step_to_cruse + B_step_breaking)) %if we have enough time to speed up and break, we can go up to the programmed speed
            B_step_start_break = B_st - B_step_breaking;      
        else %if we do not have enough steps to speed up to programmed speed, then we must reduce it
            B_step_to_cruse = round(B_st* (cnt.acc_mod/(cnt.acc_mod+cnt.breaking_mod)));
            B_step_start_break = B_step_to_cruse;
            B_step_breaking = B_st - B_step_start_break;
            if(B_speed > 0)
                B_speed = round(sqrt(cnt.min_w^2 + 2*cnt.acc_mod*cnt.d_theta*B_step_to_cruse)); %   V^2 = Vo^2 + 2*a*DS;
            else
                 B_speed = -round(sqrt(cnt.min_w^2 + 2*cnt.acc_mod*cnt.d_theta*B_step_to_cruse)); %   V^2 = Vo^2 + 2*a*DS;
            end
        end
        %calculating the duration of each phase
        B_time_speed_up = roots([cnt.acc_mod/2, cnt.min_w,  -B_step_to_cruse*cnt.d_theta]);
        B_time_speed_up = B_time_speed_up(B_time_speed_up>=0);
        B_time_cruse = (B_step_start_break-B_step_to_cruse)*cnt.d_theta/abs(B_speed);
        B_time_break = roots([-cnt.breaking_mod/2, abs(B_speed),  -B_step_breaking*cnt.d_theta]);
        B_time_break(B_time_break>=0);
        B_time_break = min(B_time_break); %I have to get the smaller time, the bigger one corresponds to go futher and return to that desired position
        B_time_break = abs(B_time_break); %due to approximations, we can have real roots
        
        B_t1 = 0:dt:(B_time_speed_up);      
        B_t2 = dt:dt:B_time_cruse;
        B_t3 = dt:dt:B_time_break;
        B_command_time = 0:dt:(B_time_speed_up+B_time_cruse+B_time_break);
        if(B_speed>0)
            B_w = [B_w cnt.min_w.*B_t1+(cnt.acc_mod/2).*B_t1.^2]; %   S = So + Vo*t + (1/2)*a*t^2  -- speed up
        else
            B_w = [B_w (cnt.min_w.*B_t1+(cnt.acc_mod/2).*B_t1.^2).*-1]; %   S = So + Vo*t + (1/2)*a*t^2  -- speed up
        end
        w_aux = B_w(end);
        if(~isempty(B_t2))                        %if there is a phase of constant speed:
            B_w = [B_w (w_aux+ B_speed.*B_t2)];
            w_aux = B_w(end);
        end
        if(B_speed>0)
            B_w = [B_w (w_aux+ B_speed.*B_t3-(cnt.breaking_mod/2).*B_t3.^2)];
        else
            B_w = [B_w (w_aux+ B_speed.*B_t3+(cnt.breaking_mod/2).*B_t3.^2)];
        end
        
        B_w(1) = [];
        rescale = abs(B_w(end)/(B_st*cnt.d_theta)); %factor to compensate the errors that will accumulate along with the reconstruction of cinematic
        B_w = B_w./rescale;
    else    %the base motor will not move, just make a delay
        B_command_time = B_st*0.001; %just tell me when is the end of the delay - every step here is equal to one millisecond 
        B_w = 0;
    end
    
    
        
    %now for the top motor
    if(abs(T_speed) >= cnt.min_w)   %if the base motor will move at this command
        T_step_to_cruse = round((T_speed^2 - cnt.min_w^2)/(2*cnt.acc_mod*cnt.d_theta)); %   V^2 = Vo^2 + 2*a*DS;
        T_step_breaking = round((T_speed^2 - cnt.min_w^2)/(2*cnt.breaking_mod*cnt.d_theta)); %   V^2 = Vo^2 + 2*a*DS;
        
        %calculating the real cruse speed, number of steps to cruse... for BASE
        %motor
        if(T_st >= (T_step_to_cruse + T_step_breaking)) %if we have enough time to speed up and break, we can go up to the programmed speed
            T_step_start_break = T_st - T_step_breaking;      
        else %if we do not have enough steps to speed up to programmed speed, then we must reduce it
            T_step_to_cruse = round(T_st* (cnt.acc_mod/(cnt.acc_mod+cnt.breaking_mod)));
            T_step_start_break = T_step_to_cruse;
            T_step_breaking = T_st - T_step_start_break;
            if(T_speed > 0)
                T_speed = round(sqrt(cnt.min_w^2 + 2*cnt.acc_mod*cnt.d_theta*T_step_to_cruse)); %   V^2 = Vo^2 + 2*a*DS;
            else
                T_speed = -round(sqrt(cnt.min_w^2 + 2*cnt.acc_mod*cnt.d_theta*T_step_to_cruse)); %   V^2 = Vo^2 + 2*a*DS;
            end
        end
        %calculating the duration of each phase
        T_time_speed_up = roots([cnt.acc_mod/2, cnt.min_w,  -T_step_to_cruse*cnt.d_theta]);
        T_time_speed_up = T_time_speed_up(T_time_speed_up>=0);
        T_time_cruse = (T_step_start_break-T_step_to_cruse)*cnt.d_theta/abs(T_speed);
        T_time_break = roots([-cnt.breaking_mod/2, abs(T_speed),  -T_step_breaking*cnt.d_theta]);
        T_time_break(T_time_break>=0);
        T_time_break = min(T_time_break); %I have to get the smaller time, the bigger one corresponds to go futher and return to that desired position
        T_time_break = abs(T_time_break);
        
        T_t1 = 0:dt:(T_time_speed_up);      
        T_t2 = dt:dt:T_time_cruse;
        T_t3 = dt:dt:T_time_break;
        T_command_time = 0:dt:(T_time_speed_up+T_time_cruse+T_time_break);
        if(T_speed>0)
            T_w = [T_w cnt.min_w.*T_t1+(cnt.acc_mod/2).*T_t1.^2]; %   S = So + Vo*t + (1/2)*a*t^2  -- speed up
        else
            T_w = [T_w (cnt.min_w.*T_t1+(cnt.acc_mod/2).*T_t1.^2).*-1]; %   S = So + Vo*t + (1/2)*a*t^2  -- speed up
        end
        w_aux = T_w(end);
        if(~isempty(T_t2))                        %if there is a phase of constant speed:
            T_w = [T_w (w_aux+ T_speed.*T_t2)];
            w_aux = T_w(end);
        end
        if(T_speed>0)
            T_w = [T_w (w_aux+ T_speed.*T_t3-(cnt.breaking_mod/2).*T_t3.^2)];
        else
            T_w = [T_w (w_aux+ T_speed.*T_t3+(cnt.breaking_mod/2).*T_t3.^2)];
        end
        
        T_w(1) = [];
        rescale = abs(T_w(end)/(T_st*cnt.d_theta)); %factor to compensate the errors that will accumulate along with the reconstruction of cinematic
        T_w = T_w./rescale;
    else    %the base motor will not move, just make a delay
        T_command_time = T_st*0.001; %just tell me when is the end of the delay - every step here is equal to one millisecond 
        T_w = 0;
     end
    
    % fusioning the time vector for the command
    % acumulating the time and the angular positions
    if(T_command_time(end)>=B_command_time(end))    %if the top motor takes longer to complete the command
        %make sure that the partial time vector has all time steps
        B_command_time = 0:dt:T_command_time(end); 
  %      B_command_time = T_command_time;
    else %if the base motor takes longer to complete the command
         %make sure that the partial time vector has all time steps
        B_command_time = 0:dt:B_command_time(end); 
      %  T_command_time = B_command_time;
    end
    %make sure all vectors have the same size. If they don't, copy the
    %last position until they have. It means that one motor wait to the
    %other to finish its command, wait in the same last position
    w_aux = B_w(end);
    B_w(numel(B_w)+1:numel(B_command_time)) = w_aux;
    w_aux = T_w(end);
    T_w(numel(T_w)+1:numel(B_command_time)) = w_aux;
    
    %concatenating the time vector
    time_aux = t(end)+dt;
    B_command_time = B_command_time+time_aux;
    t = [t B_command_time];
    
    %concatenating the base angle
    w_aux = base_angle(end);
    B_w = B_w + w_aux;
    base_angle = [base_angle B_w];
    
    %concatenating the top angle
    w_aux = top_angle(end);
    T_w = T_w + w_aux;
    top_angle = [top_angle T_w];
    
end  %FOR END
    t(1) = [];
    base_angle(1) = [];
    top_angle(1) = [];
end



    
%     if(t_speed >= cnt.min_w)
%         st_to_cruse_top = (t_speed^2 - cnt.min_w^2)/(2*cnt.acc_mod*cnt.d_theta);
%         st_breaking_top = (t_speed^2 - cnt.min_w^2)/(2*cnt.breaking_mod*cnt.d_theta);
%         
%     %calculating the real cruse speed, number of steps to cruse... for TOP
%     %motor
%     if(t_st >= (st_to_cruse_top + st_breaking_top)) %if we have enough time to speed up and break, we can go up to the programmed speed
%         st_start_breaking_top = t_st - st_breaking_top;      
%     else %if we do not have enough steps to speed up to programmed speed, then we must reduce it
%         st_to_cruse_top = t_st* (cnt.acc_mod/(cnt.acc_mod+cnt.breaking_mod));
%         st_start_breaking_top = st_to_cruse_top;
%         st_breaking_top = t_st - st_start_breaking_top;
%         t_speed = sqrt(cnt.min_w^2 + 2*cnt.acc_mod*cnt.d_theta*st_to_cruse_top);
%     end
%     end
