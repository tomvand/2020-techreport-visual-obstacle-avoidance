tab = readtable('kitti_stereo.csv');
tab.is_cpu = logical(tab.is_1core);
tab.is_multicore = ~tab.is_1core & ~tab.is_gpu;
tab.is_gpu = logical(tab.is_gpu);
tab.code_available = logical(tab.code_available);

[cols, colororder] = tudelft_colors;
opt = format_tudelft_report(); % CAUTION: remains effective after script!

%% Overview - platform
figure('Name', 'Overview - platform');
semilogx(tab.Runtime(tab.is_cpu), tab.D1_all(tab.is_cpu), 'o', 'DisplayName', 'CPU Single core'); hold all;
semilogx(tab.Runtime(tab.is_multicore), tab.D1_all(tab.is_multicore), 'o', 'DisplayName', 'CPU Multi core');
semilogx(tab.Runtime(tab.is_gpu), tab.D1_all(tab.is_gpu), 'o', 'DisplayName', 'GPU');
ylim([0 30]);
xlim([10^-3 10^5]);
xlabel('Runtime [s]');
ylabel('% Error (D1-all)');
legend('show', 'Location', 'northwest');
drawnow;
saveas(gcf, 'kitti_stereo_platform', opt.format);

%% Overview - code availability
figure('Name', 'Overview - code availability');
set(gcf, 'defaultAxesColorOrder', [cols.brightgreen; cols.red]);
semilogx(tab.Runtime(tab.code_available), tab.D1_all(tab.code_available), 'o', 'DisplayName', 'Code available'); hold all;
semilogx(tab.Runtime(~tab.code_available), tab.D1_all(~tab.code_available), '.', 'DisplayName', 'Code not available');
xlabel('Runtime [s]');
ylabel('% Error (D1-all)');
legend('show', 'Location', 'northwest');
drawnow;
saveas(gcf, 'kitti_stereo_code', opt.format);

%% Detail - code available
figure('Name', 'Detail - code available');
semilogx(tab.Runtime(tab.code_available & tab.is_cpu), tab.D1_all(tab.code_available & tab.is_cpu), 'o', 'DisplayName', 'CPU'); hold all;
% semilogx(tab.Runtime(tab.code_available & tab.is_multicore), tab.D1_all(tab.code_available & tab.is_multicore), 'o', 'DisplayName', 'CPU Multi core');
semilogx(tab.Runtime(tab.code_available & tab.is_gpu), tab.D1_all(tab.code_available & tab.is_gpu), 'o', 'DisplayName', 'GPU');
for i=1:length(tab.code_available)
    if tab.code_available(i) && tab.Runtime(i) < 10^2 && tab.D1_all(i) < 15
        text(tab.Runtime(i), tab.D1_all(i), sprintf('   %s', char(tab.Method(i))));
    end
end
xlim([-Inf, 10^2]);
ylim([-Inf, 15]);
xlabel('Runtime [s]');
ylabel('% Error (D1-all)');
legend('show', 'Location', 'northwest');
fix_text_overlap(gca);
drawnow;
saveas(gcf, 'kitti_stereo_detail', opt.format);
