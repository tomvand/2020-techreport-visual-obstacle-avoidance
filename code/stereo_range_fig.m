opt = format_tudelft_report(); % CAUTION: remains effective after script!

B = 0.20;
f = 440;
zv = 0:1000;

dv = B*f./zv;

dzddv = -B*f./(dv.^2);

%%
figure('Name', 'Disparity vs. distance');
plot(zv, dv);
xlim([0 100]);
xlabel('Distance [m]');
ylabel('Disparity [px]');
saveas(gcf, 'stereo_disparity', opt.format);

%%
figure('Name', 'Distance vs. sensitivity');
plot(zv, -dzddv);
xlim([0 100]);
xlabel('Distance [m]');
% ylabel('\sffamily Sensitivity ($-\frac{dz}{dd}$) [m/px]', 'Interpreter', 'latex');
ylabel('Sensitivity [m/px]');
saveas(gcf, 'stereo_sensitivity', opt.format);