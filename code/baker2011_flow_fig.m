tab = readtable('baker2011_flow.csv');
tab.code_available = ~strcmpi(tab.code, '');

[cols, colororder] = tudelft_colors;
opt = format_tudelft_report(); % CAUTION: remains effective after script!

%% Overview - platform
% figure('Name', 'Overview - platform');
% semilogx(tab.runtime(tab.is_cpu), tab.fl_all(tab.is_cpu), 'o', 'DisplayName', 'CPU Single core'); hold all;
% semilogx(tab.runtime(tab.is_multicore), tab.fl_all(tab.is_multicore), 'o', 'DisplayName', 'CPU Multi core');
% semilogx(tab.runtime(tab.is_gpu), tab.fl_all(tab.is_gpu), 'o', 'DisplayName', 'GPU');
% xlabel('Runtime [s]');
% ylabel('% Error (fl-all)');
% legend('show', 'Location', 'northwest');
% drawnow;
% saveas(gcf, 'kitti_flow2015_platform', opt.format);

%% Overview - code availability
figure('Name', 'Overview - code availability');
set(gcf, 'defaultAxesColorOrder', [cols.brightgreen; cols.red]);
semilogx(tab.Runtime(tab.code_available), tab.AvgEE(tab.code_available), 'o', 'DisplayName', 'Code available'); hold all;
semilogx(tab.Runtime(~tab.code_available), tab.AvgEE(~tab.code_available), '.', 'DisplayName', 'Code not available');
xlabel('Runtime [s]');
ylabel('Avg. endpoint error [px]');
legend('show', 'Location', 'northeast');
drawnow;
saveas(gcf, 'baker2011_flow_code', opt.format);

%% Detail - code available
figure('Name', 'Detail - code available');
semilogx(tab.Runtime(tab.code_available), tab.AvgEE(tab.code_available), 'o'); hold all;
for i=1:length(tab.code_available)
    if tab.code_available(i)
        text(tab.Runtime(i), tab.AvgEE(i), sprintf('   %s', char(tab.Algorithm(i))), 'Interpreter', 'none');
    end
end
xlabel('Runtime [s]');
ylabel('Avg. endpoint error [px]');
ylim([0 25]);
% legend('show', 'Location', 'northwest');
fix_text_overlap(gca);
drawnow;
saveas(gcf, 'baker2011_flow_detail', opt.format);
