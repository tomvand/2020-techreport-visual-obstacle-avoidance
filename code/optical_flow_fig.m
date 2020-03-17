opt = format_tudelft_report(); % CAUTION: remains effective after script!

zv = [10, 50, 100]; % m
zd = 10; % m/s
% f = 400; % px
uv = -400:400; % px
deltat = 0.10; % s

udv = uv./zv' * -zd;
deltauv = udv * deltat;

sensitivity = zv'.^2 ./ (zd .* uv .* deltat);

% uv2 = 0:100:400; % px
uv2 = [1, 10, 100, 400]; % px
zv2 = 0:100; % m
udv2 = uv2./zv2' * -zd;
deltauv2 = udv2 * deltat;

sensitivity2 = zv2'.^2 ./ (zd .* uv2 .* deltat);

%%
figure('Name', 'Expected flow vs image position');
for i = 1:length(zv)
    plot(uv, deltauv(i,:), 'DisplayName', sprintf('z = %dm', zv(i))); hold all;
end
legend('show');
xlabel('Image position [px]');
ylabel('Flow Δu [px]');
saveas(gcf, 'flow_s1', opt.format);

%%
figure('Name', 'Distance sensitivity vs image position');
for i = 1:length(zv)
    plot(uv, abs(sensitivity(i,:)), 'DisplayName', sprintf('z = %dm', zv(i))); hold all;
end
ylim([0 100]);
xlabel('Image position [px]');
ylabel('Sensitivity [m/px]');
legend('show');
saveas(gcf, 'flow_s2', opt.format);

%%
figure('Name', 'Expected flow vs distance');
for i = 1:length(uv2)
    plot(zv2, abs(deltauv2(:,i)), 'DisplayName', sprintf('u = %dpx', uv2(i))); hold all;
end
legend('show');
xlim([0 20]);
ylim([0 100]);
xlabel('Distance [m]');
ylabel('Flow Δu [px]');
saveas(gcf, 'flow_s3', opt.format);

%%
figure('Name', 'Sensitivity vs distance');
for i = 1:length(uv2)
    plot(zv2, abs(sensitivity2(:,i)), 'DisplayName', sprintf('u = %dpx', uv2(i))); hold all;
end
ylim([0 100]);
xlabel('Distance [m]');
ylabel('Sensitivity [m/px]');
legend('show', 'Location', 'north');
saveas(gcf, 'flow_s4', opt.format);

%%
% figure('Name', 'TTC sensitivity');
% plot(uv, abs(dTTCdud));
% ylim([0 10]);
% xlabel('u [px]');
% ylabel('Sensitivity [s/px]');

%%
% figure('Name', '???');
% plot(uv, abs(dzdud)./(zv'.^2));
% xlabel('u [px]');
% ylabel('Sensitivity / z^2 [1/(px m)]');