% Solve Logistic regression with elastic net problem:
%
%	min f(x) = g(Ax) + muf/2*sum(x.^2)
%	s.t. ||x||_1 <= rho
%	where  g(y) = 1/n*sum(log(1+exp(y)), A = [-y1a1T ; ... ; -ynanT],
%   x in R^p, ai in R^p, i = 1,...,n.
%
%	grad_g(y)    = 1/n* exp(y)./(1 + exp(y)),
%	hessian_g(y) = 1/n* diag[exp(y)./(1+exp(y)).^2],
%	grad_f(x)    = AT*grad_g(Ax) + muf*x,
%	hessian_f(x) = AT*hessian_g(Ax)*A + muf*eye(p).
%      
%% Set path
clear;
addpath(genpath(pwd));

%% Load data.
fname = 'w8a.t';
[label, ins] = libsvmread(which(fname));
data.X = ins;
data.y = label;
p    = size(data.X,2);
n    = size(data.X,1);
if nnz(data.X)/n/p <= 0.5
    data.X = sparse(data.X);
end

muf  = 1.0/n;
x0 = zeros(p,1);
rho = 10;

% Params are chosen to let the solution has sparisity at round 10 percent
Rho = [1e-2,1e-2,1e-3,1e-3,2.5e-3,5.5e-3,1e-5,2.5e-6,2.5e-6,2e-5]; 

%% Solving the problem by using proximal gradient (PG)
fprintf('************************************************************************\n')
fprintf('*********** Solving logistic regression problem by using PG ************\n')
fprintf('************************************************************************\n')
param.maxiter  = 1e4;
param.tol      = 1e-6;
param.printyes = 1;
param.printdist = 50;
hist_PG = LogRegPGSolver(data, muf, rho, x0, param);

%% Solving the problem by using accelerated proximal gradient with restarting (APG-RS)
fprintf('************************************************************************\n')
fprintf('********* Solving logistic regression problem by using APG-RS **********\n')
fprintf('************************************************************************\n')
fx    = @(x) LogRegF(data,x)+0.5*muf*norm(x(:),2)^2;
gradx = @(x) LogRegG(data,x)+muf*x;
gx    = @(x) 0;
proxg = @(x,r) ProjectOntoL1Ball(x, rho);

A = data.X;
Lf = ComputeLip(A,A',muf);
maxiters = 1e4;
tol = 1e-6;
printdist = 50;
hist_APGRS  = LogRegAPG_RS_Solver(fx, gradx, gx, proxg, Lf, x0, maxiters, tol, printdist);

%% Solving the problem by using our method (FWPN)
fprintf('************************************************************************\n')
fprintf('**** Solving logistic regression problem by using our method (FWPN) ****\n')
fprintf('************************************************************************\n')
k = 2;
temp = sparse(1:n,1:n,-data.y, n, n)*data.X;
tempt = rho*temp';
C = rho*sparse([1:p,1:p], (1:2*p), [ones(1,p),-ones(1,p)], p, 2*p);
AC = temp*C;
Options.lambda0    = 1;
Options.lambda_tol = 1e-6;
Options.sub_tol    = 0.1;
Options.short2long = 10;
Options.max_iter   = 100;
Options.sub_max_iter = max(size(AC,2), 1e+3);
get_obj = @(x) LogRegGetObj(x, AC, C, muf, n);
SubSolver = @(x, y, tol, max_iter) LogRegFWPNSubSolver(x, y, AC, tempt, C, muf, tol, max_iter);
hist_FWPN = ProxNSolver(1/2/p*ones(2*p,1), Options, SubSolver, get_obj, k);

%% Plot the result
f_star = min([hist_APGRS.obj, hist_PG.obj, hist_FWPN.obj]);
legend_fig1 = {};
MarkSize = 7;

semilogy([0, hist_FWPN.cumul_time], abs([hist_FWPN.f, hist_FWPN.obj] - f_star),...
    'o--', 'Color', [0.8500 0.3250 0.0980],...
    'MarkerEdgeColor',[0.8500 0.3250 0.0980], 'MarkerFaceColor',[0.8500 0.3250 0.0980], 'MarkerSize', MarkSize);  hold on
legend_fig1{1,1} = 'FWPN';
    
totallength = length(hist_PG.f);
dist = floor(totallength/10);
index = 1:dist:totallength;
semilogy(hist_PG.cumul_time(index), abs(hist_PG.f(index) - f_star),...
    'd-','color', [0.4660 0.6740 0.1880],...
    'MarkerEdgeColor',[0.4660 0.6740 0.1880], 'MarkerFaceColor', [0.4660 0.6740 0.1880], 'MarkerSize', MarkSize);  hold on
legend_fig1{1,2} = 'PG';

totallength = length(hist_APGRS.f);
dist = floor(totallength/10);
index = 1:dist:totallength;
semilogy(hist_APGRS.cumul_time(index), abs(hist_APGRS.f(index) - f_star),...
    'v-','color', [0 0.4470 0.7410],...
    'MarkerEdgeColor',[0 0.4470 0.7410], 'MarkerFaceColor', [0 0.4470 0.7410], 'MarkerSize', MarkSize);  hold on
legend_fig1{1,3} = 'APG-RS';

xlabel('Time($s$)', 'Interpreter', 'latex', 'FontSize', 20);

ylabel('$f(X) - f^\star$','Interpreter', 'latex', 'FontSize', 20);

title([fname, ': $n$ = ', num2str(n), ' $p$ = ', num2str(p)],'Interpreter', 'latex', 'FontSize', 20)
h1 = legend(legend_fig1); 
set(h1, 'Interpreter', 'latex', 'FontSize', 12);