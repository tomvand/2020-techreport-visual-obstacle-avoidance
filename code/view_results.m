function [] = view_results()

% Load csv file
[file, path] = uigetfile('*.csv');
if file == 0; return; end;

table = readtable(fullfile(path, file));

% Sanity checks
if ~ismember('time', table.Properties.VariableNames)
    error('No time column in table!');
end

% Load external OptiTrack file if available
ot_filename = fullfile(path, [file(1:end-4), '_optitrack.csv']);
if exist(ot_filename, 'file')
    disp('Found OptiTrack data');
    table = read_optitrack(table, ot_filename);
end

% Plot results
global tabgroup
fig = figure('Name', file);
tabgroup = uitabgroup(fig);

tab_altitude(table);
tab_trajectory(table);
tab_optitrack(table);
tab_battery(table);
tab_attitude(table);
tab_autopilot(table);
tab_timing(table);
tab_evo(table);

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% OptiTrack functions                                                     %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% OptiTrack log should contain Frame, Time, Quaternion, Position columns.
function tab_out = read_optitrack(tab, filename)
try
    % Read csv
    ot = readtable(filename, 'ReadVariableNames', false, 'HeaderLines', 2);
    columnnames = strcat(ot{4,:}', ot{5,:}')';
    ot = readtable(filename, 'ReadVariableNames', false, 'HeaderLines', 7);
    ot.Properties.VariableNames = columnnames;
    % Resample at file logger frequency
    dt_t = mean(diff(tab.time));
    ot_resampled = interp1(ot.Time, ot{:,:}, 0:dt_t:max(ot.Time), 'spline');
    ot_resampled = array2table(ot_resampled, 'VariableNames', columnnames);
    % Align time, use vertical position to synchronize
    delay = finddelay(-tab.pos_ltp_z, ot_resampled.PositionY);
    ot_sync = interp1(ot_resampled{:,:}, (1:length(tab.time)) + delay, 'spline', NaN);
    ot_sync = array2table(ot_sync, 'VariableNames', columnnames);
    ot_sync.Time = tab.time;
    % Calculate velocities
    ot_sync.VelocityX = gradient(ot_sync.PositionX) ./ gradient(ot_sync.Time);
    ot_sync.VelocityY = gradient(ot_sync.PositionY) ./ gradient(ot_sync.Time);
    ot_sync.VelocityZ = gradient(ot_sync.PositionZ) ./ gradient(ot_sync.Time);
    % Align axes to LTP
    is_moving = (tab.vel_ltp_x.^2 + tab.vel_ltp_y.^2) > 0.5 & ...
        tab.pos_ltp_z < -0.5;
    course_ltp = atan2(tab.vel_ltp_x, tab.vel_ltp_y); % cw from north
    course_ot = atan2(ot_sync.VelocityX, ot_sync.VelocityZ);
    angle = median(wrapToPi(course_ltp(is_moving) - course_ot(is_moving)));
    ot_sync.pos_ltp_ot_x = cos(angle) .* ot_sync.PositionX + sin(angle) .* ot_sync.PositionZ;
    ot_sync.pos_ltp_ot_y = -sin(angle) .* ot_sync.PositionX + cos(angle) .* ot_sync.PositionZ;
    ot_sync.pos_ltp_ot_z = -ot_sync.PositionY;
    ot_sync.vel_ltp_ot_x = cos(angle) .* ot_sync.VelocityX + sin(angle) .* ot_sync.VelocityZ;
    ot_sync.vel_ltp_ot_y = -sin(angle) .* ot_sync.VelocityX + cos(angle) .* ot_sync.VelocityZ;
    ot_sync.vel_ltp_ot_z = -ot_sync.VelocityY;
    % Calculate body-frame velocities
    % TODO use full rotation matrix instead of only psi
    if ismember('att_psi', tab.Properties.VariableNames)
        ot_sync.vel_body_ot_x = cos(tab.att_psi) .* ot_sync.vel_ltp_ot_x + sin(tab.att_psi) .* ot_sync.vel_ltp_ot_y;
        ot_sync.vel_body_ot_y = -sin(tab.att_psi) .* ot_sync.vel_ltp_ot_x + cos(tab.att_psi) .* ot_sync.vel_ltp_ot_y;
        ot_sync.vel_body_ot_z = ot_sync.vel_ltp_ot_z;
    end
    % Align start position to LTP
    start_i = find(tab.pos_ltp_z < -0.5, 1, 'first');
    ofs_x = median(ot_sync.pos_ltp_ot_x(1:start_i) - tab.pos_ltp_x(1:start_i));
    ofs_y = median(ot_sync.pos_ltp_ot_y(1:start_i) - tab.pos_ltp_y(1:start_i));
    ofs_z = median(ot_sync.pos_ltp_ot_z(1:start_i) - tab.pos_ltp_z(1:start_i));
    ot_sync.pos_ltp_ot_x = ot_sync.pos_ltp_ot_x - ofs_x;
    ot_sync.pos_ltp_ot_y = ot_sync.pos_ltp_ot_y - ofs_y;
%     ot_sync.pos_ltp_ot_z = ot_sync.pos_ltp_ot_z - ofs_z;
    % TODO rotate attitude?
    % Add OptiTrack to original table
    tab_out = [tab, ot_sync];
catch e
    disp('Error loading OptiTrack data, skipping...');
    disp(e.message);
end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Common functions                                                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function tab = add_tab(name)
global tabgroup
tab = uitab(tabgroup, 'Title', name);
axes('parent', tab);
end

function plot_condition_bar(table, condition, y, ColorSpec)
if nargin < 4
    ColorSpec = 'k';
end
plot([table.time(1), table.time(end)], [y, y], 'k');
istart = find(condition, 1, 'first');
while ~isempty(istart)
    iend = istart + find(~condition(istart:end), 1, 'first') - 2;
    if isempty(iend); iend = length(condition); end;
    h = patch([table.time(istart), table.time(iend), table.time(iend), table.time(istart)], ...
        [y-0.4, y-0.4, y+0.4, y+0.4], ...
        ColorSpec, 'EdgeColor', 'none'); hold all;
    uistack(h, 'bottom');
    istart = iend + find(condition((iend+1):end), 1 ,'first');
end
end

function shade_condition(table, condition, ColorSpec)
if nargin < 3
    ColorSpec = [0.8 0.8 0.8];
end
ylim = get(gca(), 'ylim');
istart = find(condition, 1, 'first');
while ~isempty(istart)
    iend = istart + find(~condition(istart:end), 1, 'first') - 2;
    if isempty(iend); iend = length(condition); end;
    h = patch([table.time(istart), table.time(iend), table.time(iend), table.time(istart)], ...
        [ylim(1), ylim(1), ylim(2), ylim(2)], ...
        ColorSpec, 'EdgeColor', 'none'); hold all;
    uistack(h, 'bottom');
    istart = iend + find(condition((iend+1):end), 1 ,'first');
end
end

function plot_in_flight(table) % TODO replace by plot_condition
if ismember('ap_in_flight', table.Properties.VariableNames)
    ylim = get(gca(), 'ylim');
    istart = find(~table.ap_in_flight, 1, 'first');
    while ~isempty(istart)
        iend = istart + find(table.ap_in_flight(istart:end), 1, 'first') - 2;
        if isempty(iend); iend = length(table.ap_in_flight); end;
        h = patch([table.time(istart), table.time(iend), table.time(iend), table.time(istart)], ...
            [ylim(1), ylim(1), ylim(2), ylim(2)], ...
            [0.9 0.9 0.9], 'EdgeColor', 'none'); hold all;
        uistack(h, 'bottom');
        istart = iend + find(~table.ap_in_flight((iend+1):end), 1 ,'first');
    end
end
end

function str = ap_mode_str(mode)
modestr = {
    'KILL',...
    'FAILSAFE',...
    'HOME',...
    'RATE DIRECT',...
    'ATTITUDE DIRECT',...
    'RATE RC CLIMB',...
    'ATTITUDE RC CLIMB',...
    'ATTITUDE CLIMB',...
    'RATE Z HOLD',...
    'ATTITUDE Z HOLD',...
    'HOVER DIRECT',...
    'HOVER CLIMB',...
    'HOVER Z HOLD',...
    'NAV',...
    'RC DIRECT',...
    'CARE FREE DIRECT',...
    'FORWARD',...
    'MODULE',...
    'FLIP',...
    'GUIDED'
};
str = modestr{mode+1};
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Altitude tab                                                            %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function tab_altitude(table)
add_tab('Altitude');
s0 = subplot(5,1,1);
plot_autopilot_mode(table);
s1 = subplot(5,1,[2,3]);
plot_altitude(table); hold all;
plot_baro(table);
plot_sonar_bebop(table);
plot_ot_alt(table);
xlabel('Time [s]');
ylabel('Altitude [m]');
legend('show', 'AutoUpdate', 'off');
plot([table.time(1), table.time(end)], [0, 0], 'k');
plot_in_flight(table);
s2 = subplot(5,1,[4,5]);
plot_vz(table);
xlabel('Time [s]');
ylabel('v_z [m/s]');
plot_in_flight(table);
linkaxes([s0 s1 s2], 'x');
end

function plot_altitude(table)
if ismember('pos_ltp_z', table.Properties.VariableNames)
    plot(table.time, -table.pos_ltp_z, 'DisplayName', 'INS -z');
end
end

function plot_baro(table)
if ismember('baro', table.Properties.VariableNames)
    plot(table.time, table.baro, 'DisplayName', 'Barometer');
end
end

function plot_sonar_bebop(table)
if ismember('sonar_bebop', table.Properties.VariableNames)
    plot(table.time, table.sonar_bebop, 'DisplayName', 'Sonar (Bebop)');
end
end

function plot_ot_alt(table)
if ismember('pos_ltp_ot_z', table.Properties.VariableNames)
    plot(table.time, -table.pos_ltp_ot_z, 'DisplayName', 'OptiTrack (ext)');
end
end

function plot_vz(table)
if ismember('vel_ltp_z', table.Properties.VariableNames)
    plot(table.time, -table.vel_ltp_z);
end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Trajectory tab                                                          %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function tab_trajectory(table)
add_tab('Trajectory (INS)');
plot_trajectory_3d(table);
end

function plot_trajectory_3d(table)
if ismember('pos_ltp_x', table.Properties.VariableNames)
    plot3(table.pos_ltp_y, table.pos_ltp_x, -table.pos_ltp_z); hold all; % Note: NED to ENU
    set(gca, 'ColorOrderIndex', 1);
    plot3(table.pos_ltp_y, table.pos_ltp_x, zeros(size(table.pos_ltp_z)), ':');
    set(gca, 'ColorOrderIndex', 1);
    tvec = ceil(table.time(1)):1:table.time(end);
    [~,ia] = unique(table.time);
    plot3(interp1(table.time(ia), table.pos_ltp_y(ia), tvec), ...
        interp1(table.time(ia), table.pos_ltp_x(ia), tvec), ...
        interp1(table.time(ia), -table.pos_ltp_z(ia), tvec), ...
        '.', 'MarkerSize', 10);
end
grid on;
axis equal;
zlim([0 Inf]);
xlabel('E (y) [m]');
ylabel('N (x) [m]');
zlabel('U (-z) [m]');
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% OptiTrack tab                                                           %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function tab_optitrack(table)
if ismember('pos_ltp_ot_x', table.Properties.VariableNames)
    add_tab('OptiTrack (ext)');
    plot_optitrack_2d(table);
end
end

function plot_optitrack_2d(table)
plot(table.pos_ltp_ot_y, table.pos_ltp_ot_x, 'DisplayName', 'OptiTrack (external)'); hold all;
plot(table.pos_ltp_y, table.pos_ltp_x, 'DisplayName', 'INS');
axis equal;
grid on;
xlabel('E (y) [m]');
ylabel('N (x) [m]');
legend('show', 'AutoUpdate', 'off');
set(gca, 'ColorOrderIndex', 1);
plot(table.pos_ltp_ot_y(1), table.pos_ltp_ot_x(1), 'o');
plot(table.pos_ltp_y(1), table.pos_ltp_x(1), 'o');
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Velocity tab                                                            %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function tab_velocity(table)
add_tab('Velocity');
plot_velocity_2d(table);
end

function plot_velocity_2d(table)
if ismember('pos_ltp_x', table.Properties.VariableNames)
    if ismember('vel_ltp_x', table.Properties.VariableNames)
        plot(table.pos_ltp_y, table.pos_ltp_x, 'DisplayName', 'INS LTP POS'); hold all; % NED to ENU
        quiver(table.pos_ltp_y, table.pos_ltp_x, ...
            table.vel_ltp_y, table.vel_ltp_x, 3, 'DisplayName', 'INS LTP');
    end
    if ismember('vel_body_x', table.Properties.VariableNames) && ...
            ismember('att_psi', table.Properties.VariableNames)
        vned = NaN(2, length(table.vel_body_x));
        for i=1:length(table.vel_body_x)
            R = [cos(table.att_psi(i)), -sin(table.att_psi(i));
                 sin(table.att_psi(i)), cos(table.att_psi(i))];
            vned(:, i) = R * [table.vel_body_x(i); table.vel_body_y(i)];
        end
        quiver(table.pos_ltp_y, table.pos_ltp_x, ...
            vned(2,:).', vned(1,:).', 3, 'DisplayName', 'Body vel');
    end
end
axis equal;
grid on;
xlabel('E (y) [m]');
ylabel('N (x) [m]');
legend('show', 'AutoUpdate', 'off');
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Battery tab                                                             %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function tab_battery(table)
add_tab('Battery');
plot_vsupply(table); hold all;
xlabel('Time [s]');
ylabel('Voltage [V]');
plot_in_flight(table);
if ismember('bat_crit', table.Properties.VariableNames) && ...
        ismember('bat_low', table.Properties.VariableNames)
    shade_condition(table, table.bat_crit, 0.5*[1 0.5 0] + 0.5);
    shade_condition(table, table.bat_low, 0.5*[1 1 0] + 0.5);
end
end

function plot_vsupply(table)
if ismember('v_supply', table.Properties.VariableNames)
    plot(table.time, table.v_supply);
end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Attitude tab                                                            %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function tab_attitude(table)
add_tab('Attitude');
s1 = subplot(5,1,1:4);
plot_phi(table); hold all;
plot_theta(table);
xlabel('Time [s]');
ylabel('Angle [deg]');
legend('show', 'AutoUpdate', 'off');
plot_in_flight(table);
s2 = subplot(5,1,5);
plot_psi(table); hold all;
xlabel('Time [s]');
ylabel('Angle [deg]');
legend('show', 'AutoUpdate', 'off');
plot_in_flight(table);
linkaxes([s1 s2], 'x');
end

function plot_phi(table)
if ismember('att_phi', table.Properties.VariableNames)
    plot(table.time, rad2deg(table.att_phi), 'DisplayName', '\phi');
end
end

function plot_theta(table)
if ismember('att_theta', table.Properties.VariableNames)
    plot(table.time, rad2deg(table.att_theta), 'DisplayName', '\theta');
end
end

function plot_psi(table)
if ismember('att_phi', table.Properties.VariableNames)
    plot(table.time, rad2deg(table.att_psi), 'DisplayName', 'Heading \psi');
end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Autopilot tab                                                           %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function tab_autopilot(table)
add_tab('Autopilot');
s1 = subplot(4,1,1);
plot_autopilot_status(table);
s2 = subplot(4,1,2);
plot_autopilot_mode(table);
s3 = subplot(4,1,3);
plot_flightplan_status(table);
s4 = subplot(4,1,4);
plot_autopilot_dt(table);
linkaxes([s1 s2 s3 s4], 'x');
end

function plot_autopilot_status(table)
axis ij;
if ismember('ap_motors_on', table.Properties.VariableNames)
    plot_condition_bar(table, table.ap_motors_on, 1); hold all;
end
if ismember('ap_kill_throttle', table.Properties.VariableNames)
    plot_condition_bar(table, table.ap_kill_throttle, 2);
end
if ismember('ap_in_flight', table.Properties.VariableNames)
    plot_condition_bar(table, table.ap_in_flight, 3);
end
xlabel('Time [s]');
yticks([1 2 3]);
yticklabels({'motors on', 'kill throttle', 'in flight'});
end

function plot_autopilot_mode(table)
if ismember('ap_mode', table.Properties.VariableNames)
    axis ij; hold all;
    plot(table.time, table.ap_mode, 'LineWidth', 2);
    xlabel('Time [s]');
    ylabel('Mode');
    yticks(0:19);
    ylim([0 19]);
    mode_changed = [1; find(diff(table.ap_mode)) + 1];
    for i = mode_changed'
        text(table.time(i), table.ap_mode(i), ap_mode_str(table.ap_mode(i)), ...
            'VerticalAlignment', 'bottom');
    end
end
end

function plot_flightplan_status(table)
if ismember('block', table.Properties.VariableNames) && ...
        ismember('stage', table.Properties.VariableNames)
    axis ij; hold all;
    plot(table.time, table.block, 'DisplayName', 'block', 'LineWidth', 2);
    plot(table.time, table.stage, 'DisplayName', 'stage', 'LineWidth', 2);
    xlabel('Time [s]');
    legend('show', 'AutoUpdate', 'off');
    plot_in_flight(table);
    if ismember('bat_low', table.Properties.VariableNames) && ...
            ismember('bat_crit', table.Properties.VariableNames)
        shade_condition(table, table.bat_crit, 0.5*[1 0.5 0] + 0.5);
        shade_condition(table, table.bat_low, 0.5*[1 1 0] + 0.5);
    end
    yticks(0:255);
end
end

function plot_autopilot_dt(table)
if ismember('time', table.Properties.VariableNames)
    plot(table.time(2:end), diff(table.time));
    xlabel('Time [s]');
    ylabel('dt [s]');
end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Timing tab                                                              %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function tab_timing(table)
add_tab('Timing');
plot(table.time(2:end), diff(table.time), 'DisplayName', 'dt'); hold all;
if ismember('file_logger_time', table.Properties.VariableNames)
    plot(table.time, table.file_logger_time, 'DisplayName', 'file logger');
end
legend('show', 'AutoUpdate', 'off');
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% eVO tab                                                                 %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function tab_evo(table)
if ismember('percevite_vx', table.Properties.VariableNames) && ...
        ismember('vel_body_x', table.Properties.VariableNames)
    add_tab('eVO');
    s1 = subplot(4,2,1);
    if ismember('vel_body_ot_x', table.Properties.VariableNames)
        plot(table.time, table.vel_body_ot_x, 'DisplayName', 'OptiTrack (ext)'); hold all;
    end
    plot(table.time, table.vel_body_x, 'DisplayName', 'INS'); hold all;
    plot(table.time, table.percevite_vx, 'DisplayName', 'eVO');
    xlabel('time [s]');
    ylabel('vx [m/s]');
    legend('show', 'AutoUpdate', 'off');
    plot_in_flight(table);
    shade_condition(table, ~table.percevite_ok, [1 0 0]*0.2 + 0.8);
    
    s2 = subplot(4,2,3);
    if ismember('vel_body_ot_y', table.Properties.VariableNames)
        plot(table.time, table.vel_body_ot_y, 'DisplayName', 'OptiTrack (ext)'); hold all;
    end
    plot(table.time, table.vel_body_y, 'DisplayName', 'INS'); hold all;
    plot(table.time, table.percevite_vy, 'DisplayName', 'eVO');
    xlabel('time [s]');
    ylabel('vy [m/s]');
    legend('show', 'AutoUpdate', 'off');
    plot_in_flight(table);
    shade_condition(table, ~table.percevite_ok, [1 0 0]*0.2 + 0.8);
    
    s3 = subplot(4,2,5);
    if ismember('vel_body_ot_z', table.Properties.VariableNames)
        plot(table.time, table.vel_body_ot_z, 'DisplayName', 'OptiTrack (ext)'); hold all;
    end
    plot(table.time, table.vel_body_z, 'DisplayName', 'INS'); hold all;
    plot(table.time, table.percevite_vz, 'DisplayName', 'eVO');
    xlabel('time [s]');
    ylabel('vz [m/s]');
    legend('show', 'AutoUpdate', 'off');
    plot_in_flight(table);
    shade_condition(table, ~table.percevite_ok, [1 0 0]*0.2 + 0.8);
    
    s4 = subplot(4,2,7);
    plot(table.time, table.percevite_time_since_vel, 'DisplayName', 'Vel'); hold all;
    plot(table.time, table.percevite_time_since_dist, 'DisplayName', 'Dist');
    xlabel('Time [s]');
    ylabel('Time since update [s]');
    legend('show', 'AutoUpdate', 'off');
    shade_condition(table, ~table.percevite_ok, [1 0 0]*0.2 + 0.8);
    plot_in_flight(table);
    
    linkaxes([s1 s2 s3 s4], 'x');
    
    d = [0; diff(table.percevite_vx)];
    new_data = d~=0;
    
    s5 = subplot(4,2,[2,4]);
    if ismember('vel_body_ot_x', table.Properties.VariableNames)
        vx_err = table.percevite_vx - table.vel_body_ot_x;
        vy_err = table.percevite_vy - table.vel_body_ot_y;
        vz_err = table.percevite_vz - table.vel_body_ot_z;
        source = 'OptiTrack (ext)';
    else
        vx_err = table.percevite_vx - table.vel_body_x;
        vy_err = table.percevite_vy - table.vel_body_y;
        vz_err = table.percevite_vz - table.vel_body_z;
        source = 'INS';
    end
    Rx = mean(vx_err(table.percevite_ok~=0 & new_data).^2);
    Ry = mean(vy_err(table.percevite_ok~=0 & new_data).^2);
    Rz = mean(vz_err(table.percevite_ok~=0 & new_data).^2);
    plot(vy_err(table.percevite_ok==0 & new_data), vx_err(table.percevite_ok==0 & new_data), ...
        '.', 'Color', [1 0 0]*0.2 + 0.8, 'DisplayName', 'invalid'); hold all;
    set(gca, 'ColorOrderIndex', 1);
    plot(vy_err(table.percevite_ok~=0 & new_data), vx_err(table.percevite_ok~=0 & new_data), ...
        '.', 'DisplayName', 'ok');
    xlabel('vy error [m/s]');
    ylabel('vx error [m/s]');
    axis equal;
    legend('show', 'AutoUpdate', 'off');
    title(sprintf('%s error: Rx = %.2f, Ry = %.2f, Rz = %.2f', source, Rx, Ry, Rz));
    
    s6 = subplot(4,2,[6,8]);
    if ismember('vel_body_ot_x', table.Properties.VariableNames)
        plot(table.vel_body_ot_x(table.percevite_ok~=0 & new_data), table.percevite_vx(table.percevite_ok~=0 & new_data), ...
            '.', 'DisplayName', 'x'); hold all;
        plot(table.vel_body_ot_y(table.percevite_ok~=0 & new_data), table.percevite_vy(table.percevite_ok~=0 & new_data), ...
            '.', 'DisplayName', 'y');
        plot(table.vel_body_ot_z(table.percevite_ok~=0 & new_data), table.percevite_vz(table.percevite_ok~=0 & new_data), ...
            '.', 'DisplayName', 'z');
        source = 'OptiTrack (ext)';
    else
        plot(table.vel_body_x(table.percevite_ok~=0 & new_data), table.percevite_vx(table.percevite_ok~=0 & new_data), ...
            '.', 'DisplayName', 'x'); hold all;
        plot(table.vel_body_y(table.percevite_ok~=0 & new_data), table.percevite_vy(table.percevite_ok~=0 & new_data), ...
            '.', 'DisplayName', 'y');
        plot(table.vel_body_z(table.percevite_ok~=0 & new_data), table.percevite_vz(table.percevite_ok~=0 & new_data), ...
            '.', 'DisplayName', 'z');
        source = 'INS';
    end
    xlabel(sprintf('True velocity (%s) [m/s]', source));
    ylabel('Measured velocity [m/s]');
    xticks(-10:10);
    yticks(-10:10);
    axis equal;
    grid on;
    legend('show', 'AutoUpdate', 'off');
end
end