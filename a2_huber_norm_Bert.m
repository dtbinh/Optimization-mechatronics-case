%% fitting a circle to a set of points

clear all;
close all;
clc;

%% Huber norm

opti = casadi.Opti();

r = 1;

% huber norm parameters
lambda = 1;
mu = 5;

data = [1 0; 2-sqrt(2)/2 sqrt(2)/2; 2 1;2.5 0; 2 -1]';
N = size(data,2);

p = opti.variable(2,1);

%e = sqrt(sum((data-repmat(p,1,N)).^2,1))'-r;

% create a huber norm lookup table
N = 200; % amount of interpolation points in a direction

data_xmin = min(data(1,:));
data_xmax = max(data(1,:));
data_ymin = min(data(2,:));
data_ymax = max(data(2,:));

% set initial values
% Als je een set_initial doet op p met als initi�le waarde het gemiddelde 
    %van data_xmin en data_xmax (en hetzelfde voor y), convergeert hij wel naar iets logisch. 
opti.set_initial(p{1},(data_xmin+data_xmax)/2);
opti.set_initial(p{2},(data_ymin+data_ymax)/2);


xgrid = linspace(data_xmin-1.5*r, data_xmax+1.5*r, N);
ygrid = linspace(data_ymin-1.5*r, data_ymax+1.5*r, N);
[X_lut, Y_lut] = ndgrid(xgrid, ygrid); % interpolation points

huber_lut = zeros(size(X_lut));
for i=1:size(huber_lut,1)
    for j=1:size(huber_lut,2)
        for k = 1:size(data,2)
            difference = data(:,k) - [X_lut(i,j); Y_lut(i,j)];
            error = difference - r*difference/norm(difference);
            one_norm = abs(error(1))+abs(error(2));
            if one_norm >= lambda/(2*mu)
                huber_lut(i,j) = huber_lut(i,j) + lambda*(one_norm-lambda/(4*mu));
            else
                huber_lut(i,j) = huber_lut(i,j) + mu*error'*error;
            end
        end
    end
end

LUT = casadi.interpolant('LUT', 'bspline', {xgrid, ygrid}, huber_lut(:));
opti.minimize(LUT([p(1) p(2)]));

% make sure the point stays within the LUT bounds
opti.subject_to(xgrid(1) < p(1) < xgrid(end));
opti.subject_to(ygrid(1) < p(2) < ygrid(end));

opti.solver('ipopt');

sol = opti.solve();

figure()
hold on
plot(data(1,:),data(2,:),'o')
arc = 0:0.01:2*pi;
circle = plot(sol.value(p(1))+r*cos(arc), sol.value(p(2))+r*sin(arc),'r');
axis equal
legend('data','Huber')

fprintf('Optimal location: (%f,%f)\n', sol.value(p(1)), sol.value(p(2)))

% Plot cost function for error vector (x,y)
[X,Y] = meshgrid(linspace(-2,2), linspace(-2,2));
Z = zeros(size(X));

for i = 1:size(X,1)
    for j = 1:size(X,2)
        z = [X(i,j);Y(i,j)];                             
        l_11_z = sum(abs(z),1);                             % 1 norm of each error vector in z
        l_22_z = sum(z.^2,1);                               % squared 2 norm of each error vector in z

        rh_lin = lambda*(l_11_z - lambda/(4*mu));         % upper equation of the huber norm factors
        rh_quad = mu*l_22_z;                               % lower equation of the huber norm
        rh_trans = mu*(lambda/(2*mu))^2;                      % value of rh for which it switches its case
        rh_quad_mod = -abs(rh_quad-rh_trans) + rh_trans;  % modified version of the lower equation that's only bigger than the upper equation when norm(z,1) >= lambda/(2*mu)
        rh = max(rh_lin, rh_quad_mod);                   % effective value of rh for every z
        
        Z(i,j) = rh;
    end
end

figure
mesh(X,Y,Z)
rotate3d on
xlabel('x')
ylabel('y')

% %% Rest of example code that unnecessary for our problem case
% 
% [X,Y] = meshgrid(linspace(0,3),linspace(-2,2));
% 
% for pow=1:2
%     Z = zeros(size(X));
%     for i=1:size(X,1)
%        for j=1:size(X,2)
%           pnum = [X(i,j);Y(i,j)];
%           e = sqrt(sum((data-repmat(pnum,1,N)).^2,1))'-r;
%           Z(i,j) = norm(e,2)^pow; 
%        end
%     end
% 
%     figure
%     mesh(X,Y,Z)
%     view([38,10])
% 
%     xlabel('x')
%     ylabel('y')
% end


%% 2 norm for comparison
opti2 = casadi.Opti();       % initializing optimazation problem

x = opti2.variable(1,1);     % initiializing unknown variables
y = opti2.variable(1,1);

opti2.set_initial(x,(data_xmin+data_xmax)/2);
opti2.set_initial(y,(data_ymin+data_ymax)/2);

% data = [1   2-(sqrt(2)/2)   2   3   2;
%         0   sqrt(2)/2       1   0   -1];
data = [1   2-(sqrt(2)/2)   2   2.5   2;
        0   sqrt(2)/2       1   0   -1];

% gradually building the cost function (2 norm) 
var = 0;

for index=1:1:5
    var = var + (sqrt( (x - data(1,index))^2 + (y - data(2,index))^2) - 1)^2;
end

% searching solution
opti2.minimize (var);
%opti.subject_to (x^2+y ^2 <=1)
%opti.subject_to (x+y >=0)
opti2.solver ('ipopt');
sol2 = opti2.solve();
px = sol2.value (x)
py = sol2.value (y)


% plotting solution
r = 1;



figure()
plot(data(1,:),data(2,:),'o')

hold on
th = linspace(0,2*pi,100);          % begin, einde, aantal punten
plot(r*cos(th) + px, r*sin(th) + py)
hold off
axis equal


% plotting mesh with 2 norm
[X,Y] = meshgrid(linspace(0,3),linspace(-2,2));
N = size(data,2);           % get the size of the data


Z_2_norm = zeros(size(X));
for i=1:size(X,1)
   for j=1:size(X,2)
      pnum = [X(i,j);Y(i,j)];
      e = sqrt(sum((data-repmat(pnum,1,N)).^2,1))'-r;
      Z_2_norm(i,j) = norm(e,2); 
   end
end



figure
mesh(X,Y,Z_2_norm)


%% Comparison of results


figure()
hold on
plot(data(1,:),data(2,:),'o')
arc = 0:0.01:2*pi;
circle = plot(sol.value(p(1))+r*cos(arc), sol.value(p(2))+r*sin(arc),'r');
axis equal
plot(r*cos(th) + px, r*sin(th) + py,'b');
legend('data','Huber','2 norm');


figure
mesh(X,Y,Z)
rotate3d on
hold on
xlabel('x')
ylabel('y')
mesh(X,Y,Z_2_norm)

legend('Huber','2 norm');