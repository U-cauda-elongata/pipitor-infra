package 'ruby'

directory '/opt/kf-calendar/share'
directory '/opt/kf-calendar/share/calendar' do
  owner 'pipitor'
  group 'pipitor'
end
git '/opt/kf-calendar/share/calendar' do
  repository 'https://github.com/U-cauda-elongata/calendar.git'
  user 'pipitor'
end

directory '/opt/kf-calendar/bin'
remote_file '/opt/kf-calendar/bin/calendar-update-feeds' do
  mode '755'
end

directory '/opt/kf-calendar/etc/systemd/system'
service_template '/opt/kf-calendar/etc/systemd/system/calendar-update-feeds.service'
service_file '/opt/kf-calendar/etc/systemd/system/calendar-update-feeds.timer'

service 'calendar-update-feeds.timer' do
  action :start
end
