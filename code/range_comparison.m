opt = format_tudelft_report(); % CAUTION: remains effective after script!

% Conf
z = 1:1000;

B = 0.20; % m
f = 400; % px

zdot = 10; % m/s
dt = 0.1; % s
u = [1; 100; 400]; % px

L = 10; % m

A = 100; % m

% Errors
ed = 0.1; % px
ef = 1.0; % px
el = 2.0; % px
eL = 3.0; % m
eA = 10.0; % m

% Stereo
stereo = ed * z.^2 / (B*f);

% Optical flow
flow = ef * z.^2 ./ (zdot * u * dt);

% Appearance (object size)
app = el * z.^2 / (f*L) + eL * z / L;

% Appearance (vertical position)
alt = el * z.^2 / (f*A) + eA * z / A;

%%
figure('Name', 'Depth error comparison');
plot(z, stereo, 'DisplayName', 'Stereo'); hold all;
for i=1:length(u)
    plot(z, flow(i,:), '--', 'DisplayName', sprintf('Optical flow, u = %d px', u(i)));
end
plot(z, app, 'DisplayName', 'Appearance (object size)');
plot(z, alt, 'DisplayName', 'Appearance (vertical position)');
xlim([0 200]);
ylim([0 50]);
xlabel('Distance [m]');
ylabel('Expected error [m]');
legend('show', 'Location', 'northwest');
set(gcf, opt.size.wide);
saveas(gcf, 'range_comparison', opt.format);