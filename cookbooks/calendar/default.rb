node.validate! do
  {
    calendar: {
      yt_api_key: string,
    },
  }
end

package 'ruby'

user 'kf_calendar'

directory '/opt/kf-calendar/share'
directory '/opt/kf-calendar/share/calendar' do
  owner 'kf_calendar'
  group 'kf_calendar'
end
git '/opt/kf-calendar/share/calendar' do
  repository 'https://github.com/U-cauda-elongata/calendar.git'
  user 'kf_calendar'
end
file '/opt/kf-calendar/share/calendar/yt_api_key.txt' do
  owner 'kf_calendar'
  group 'kf_calendar'
  mode '600'
  content node['calendar']['yt_api_key']
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
