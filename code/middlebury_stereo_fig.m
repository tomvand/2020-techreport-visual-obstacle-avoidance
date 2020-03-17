tab = readtable('middlebury_stereo.csv');
tab.is_gpu = strcmpi(tab.is_gpu, 'TRUE');
tab.is_multicore = strcmpi(tab.is_multicore, 'TRUE');
tab.is_cpu = ~tab.is_gpu & ~tab.is_multicore;
tab.code_unavailable = strcmpi(tab.CodeLink, '0');
tab.code_available = ~strcmpi(tab.CodeLink, '') & ~tab.code_unavailable;
tab.code_unknown = ~tab.code_available & ~tab.code_unavailable;

[cols, colororder] = tudelft_colors;
opt = format_tudelft_report(); % CAUTION: remains effective after script!

%% Overview - platform
figure('Name', 'Overview - platform');
semilogx(tab.AvgTime_GD(tab.is_cpu), tab.AvgBad2_0(tab.is_cpu), 'o', 'DisplayName', 'CPU Single core'); hold all;
semilogx(tab.AvgTime_GD(tab.is_multicore), tab.AvgBad2_0(tab.is_multicore), 'o', 'DisplayName', 'CPU Multi core');
semilogx(tab.AvgTime_GD(tab.is_gpu), tab.AvgBad2_0(tab.is_gpu), 'o', 'DisplayName', 'GPU');
xlabel('Time / GDE [s]');
ylabel('% Error > 2.0 px');
legend('show', 'Location', 'northwest');
drawnow;
saveas(gcf, 'middlebury_stereo_platform', opt.format);

%% Overview - code availability
figure('Name', 'Overview - code availability');
set(gcf, 'defaultAxesColorOrder', [cols.brightgreen; cols.red; cols.gray]);
semilogx(tab.AvgTime_GD(tab.code_available), tab.AvgBad2_0(tab.code_available), 'o', 'DisplayName', 'Code available'); hold all;
semilogx(tab.AvgTime_GD(tab.code_unavailable), tab.AvgBad2_0(tab.code_unavailable), '.', 'DisplayName', 'Code not available');
semilogx(tab.AvgTime_GD(tab.code_unknown), tab.AvgBad2_0(tab.code_unknown), '.', 'DisplayName', 'Not checked');
xlabel('Time / GDE [s]');
ylabel('% Error > 2.0 px');
legend('show', 'Location', 'northwest');
drawnow;
saveas(gcf, 'middlebury_stereo_code', opt.format);

%% Detail - code available
figure('Name', 'Detail - code available');
semilogx(tab.AvgTime_GD(tab.code_available & tab.is_cpu), tab.AvgBad2_0(tab.code_available & tab.is_cpu), 'o', 'DisplayName', 'CPU'); hold all;
semilogx(tab.AvgTime_GD(tab.code_available & tab.is_multicore), tab.AvgBad2_0(tab.code_available & tab.is_multicore), 'o', 'DisplayName', 'CPU Multi core');
semilogx(tab.AvgTime_GD(tab.code_available & tab.is_gpu), tab.AvgBad2_0(tab.code_available & tab.is_gpu), 'o', 'DisplayName', 'GPU');
for i=1:length(tab.code_available)
    if tab.code_available(i)
        text(tab.AvgTime_GD(i), tab.AvgBad2_0(i), sprintf('   %s (%s)', char(tab.Name(i)), char(tab.Res(i))));
    end
end
xlabel('Time / GDE [s]');
ylabel('% Error > 2.0 px');
legend('show', 'Location', 'east');
fix_text_overlap(gca);
drawnow;
saveas(gcf, 'middlebury_stereo_detail', opt.format);
