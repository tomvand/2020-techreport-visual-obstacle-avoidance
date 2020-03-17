tab = readtable('KITTI_flow2015.csv');
tab.is_cpu(isnan(tab.is_cpu)) = 0;
tab.is_cpu = logical(tab.is_cpu);
tab.is_multicore(isnan(tab.is_multicore)) = 0;
tab.is_multicore = logical(tab.is_multicore);
tab.is_gpu(isnan(tab.is_gpu)) = 0;
tab.is_gpu = logical(tab.is_gpu);
tab.code_available = strcmpi(tab.code, 'code');

[cols, colororder] = tudelft_colors;
opt = format_tudelft_report(); % CAUTION: remains effective after script!

%% Overview - platform
figure('Name', 'Overview - platform');
semilogx(tab.runtime(tab.is_cpu), tab.fl_all(tab.is_cpu), 'o', 'DisplayName', 'CPU Single core'); hold all;
semilogx(tab.runtime(tab.is_multicore), tab.fl_all(tab.is_multicore), 'o', 'DisplayName', 'CPU Multi core');
semilogx(tab.runtime(tab.is_gpu), tab.fl_all(tab.is_gpu), 'o', 'DisplayName', 'GPU');
xlabel('Runtime [s]');
ylabel('% Error (fl-all)');
legend('show', 'Location', 'northwest');
drawnow;
saveas(gcf, 'kitti_flow2015_platform', opt.format);

%% Overview - code availability
figure('Name', 'Overview - code availability');
set(gcf, 'defaultAxesColorOrder', [cols.brightgreen; cols.red]);
semilogx(tab.runtime(tab.code_available), tab.fl_all(tab.code_available), 'o', 'DisplayName', 'Code available'); hold all;
semilogx(tab.runtime(~tab.code_available), tab.fl_all(~tab.code_available), '.', 'DisplayName', 'Code not available');
xlabel('Runtime [s]');
ylabel('% Error (fl-all)');
legend('show', 'Location', 'northwest');
drawnow;
saveas(gcf, 'kitti_flow2015_code', opt.format);

%% Detail - code available
figure('Name', 'Detail - code available');
semilogx(tab.runtime(tab.code_available & tab.is_cpu), tab.fl_all(tab.code_available & tab.is_cpu), 'o', 'DisplayName', 'CPU Single core'); hold all;
semilogx(tab.runtime(tab.code_available & tab.is_multicore), tab.fl_all(tab.code_available & tab.is_multicore), 'o', 'DisplayName', 'CPU Multi core');
semilogx(tab.runtime(tab.code_available & tab.is_gpu), tab.fl_all(tab.code_available & tab.is_gpu), 'o', 'DisplayName', 'GPU');
xmax = 10.0;
% ymax = 100.0;
for i=1:length(tab.code_available)
    if tab.code_available(i) && tab.runtime(i) < xmax
        text(tab.runtime(i), tab.fl_all(i), sprintf('   %s', char(tab.name(i))), 'Interpreter', 'none');
    end
end
xlim([-Inf xmax]);
% ylim([-Inf ymax]);
xlabel('Runtime [s]');
ylabel('% Error (fl-all)');
legend('show', 'Location', 'northwest');
fix_text_overlap(gca);
drawnow;
saveas(gcf, 'kitti_flow2015_detail', opt.format);
