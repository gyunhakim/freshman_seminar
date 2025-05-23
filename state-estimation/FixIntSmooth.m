function [Errf, Errb, Errs] = FixIntSmooth(duration, dt, measnoise)

% function FixIntSmooth(duration, dt, measnoise)
% Fixed integer smoother simulation for a vehicle with position and velocity states
% Forward-backward smoother
% INPUTS
%   duration = length of simulation (seconds)
%   dt = step size (seconds)
%   measnoise = standard deviation of measurement noise
% OUTPUTS
%   Errf = norm of state estimation error of the forward filter at the desired time of estimation
%   Errb = norm of state estimation error of the backward filter at the desired time of estimation
%   Errf = norm of state estimation error of the smoothed filter at the desired time of estimation

accelnoise = 10; % acceleration noise (feet/sec^2)
if ~exist('duration', 'var')
   duration = 10;
end
if ~exist('dt', 'var')
   dt = 0.1;
end
if ~exist('measnoise', 'var')
	measnoise = 10; % position measurement noise (feet)
end
% We want to obtain a smoothed estimate at the halfway point
EstPoint = duration / 2;
N = round(duration / dt); % number of time steps (not including initial time step)
Nf = round(EstPoint / dt); % number of time steps in forward filter (not including initial time step)
Nb = N - Nf; % number of time steps in backward filter
a = [1 dt; 0 1]; % transition matrix
b = [dt^2/2; dt]; % input matrix
c = [1 0]; % measurement matrix
x = [0; 0]; % initial state vector
Sw = accelnoise^2 * [dt^4/4 dt^3/2; dt^3/2 dt^2]; % process noise covariance
Sz = measnoise^2; % measurement error covariance
yArr = zeros(1, N+1);
% Simulate the system and collect the measurements
% Use a constant acceleration input
u = 10;
for k = 0 : N
    if k == Nf
        xTrue = x;
    end
    ProcessNoise = accelnoise * [(dt^2/2)*randn; dt*randn];
    x = a * x + b * u + ProcessNoise;
    y = c * x + measnoise * randn;
    yArr(k+1) = y;
end
% Obtain the forward estimate
Pf = [20 0; 0 20]; % initial forward estimation covariance
PfArr = zeros(1, Nf+1);
xhatf = x + sqrt(Pf) * ones(size(x)); % initial state estimate
index = 1;
for t = 0 : dt : EstPoint
   % Extrapolate the most recent state estimate to the present time
   xhatf = a * xhatf + b * u;
   % Form the Innovation vector.
   Inn = yArr(index) - c * xhatf;
   % Compute the covariance of the Innovation
   CovInn = c * Pf * c' + Sz;
   % Compute the covariance of the estimation error
   Pf = a * Pf * a' - a * Pf * c' / CovInn * c * Pf * a' + Sw;
   % Form the Kalman Gain matrix
   K = a * Pf * c' / CovInn;
   % Update the state estimate
   xhatf = xhatf + K * Inn;
   % Save some parameters for plotting later
   PfArr(index) = trace(Pf);
   % Increment the pointer to the measurement array
   index = index + 1;
end
Errf = norm(xTrue - xhatf);
% Obtain the backward estimate
% The initial backward information matrix Ibminus needs to be set to a
% small nonzero matrix so that the first calculated Ibplus is invertible
Ibminus = [0 0; 0 1e-12]; 
PbArr = zeros(1, Nb);
s = zeros(size(x)); % initial backward modified estimate
index = N + 1;
Sw = Sw + [0 0; 0 0]; 
for t = duration : -dt : EstPoint + dt
    Ibplus = Ibminus + c' / Sz * c;
    s = s + c' / Sz * yArr(index);
    % The following line does not work unless Sw is invertible
    %Ibminus = inv(Sw) - inv(Sw) * inv(a) * inv(Ibplus + inv(a)' * inv(Sw) * inv(a)) * inv(a)' * inv(Sw);
    Ibminus = inv(inv(a) / Ibplus / a' + Sw);
    s = Ibminus / a / (Ibplus) * s - Ibminus / a * b * u;
    % Save some parameters for plotting later
    Pbminus = inv(Ibminus);
    PbArr(N-index+2) = trace(Pbminus);
    % Decrement the pointer to the measurement array
    index = index - 1;
end
xhatb = Ibminus \ s;
Errb = norm(xTrue - xhatb);
% Obtain the smoothed estimate
Kf = Pbminus / (Pf + Pbminus);
xhat = Kf * xhatf + (eye(2) - Kf) * xhatb;
Errs = norm(xTrue - xhat);
disp(['forward error = ', num2str(Errf), ', backward error = ', num2str(Errb), ', smoothed error = ', num2str(Errs)]);
% Compute the smoothed estimation covariance
close all; figure
P = inv(inv(Pf) + Ibminus);
set(gca,'FontSize',12); set(gcf,'Color','White');
plot(0:dt:EstPoint, PfArr, 'b', duration:-dt:EstPoint+dt, PbArr, 'r', EstPoint, trace(P), 'ko');
hold on
plot(EstPoint, PfArr(end), 'bo', EstPoint+dt, PbArr(end), 'ro');
axis([0 duration 0 2*max(PfArr)]);
xlabel('Time step'); ylabel('Trace of estimation covariance');
