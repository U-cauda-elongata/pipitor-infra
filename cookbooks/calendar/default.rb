node.validate! do
  {
    calendar: {
      yt_api_key: string,
    },
  }
end

package 'ruby'

user 'kf_calendar'
directory '/home/kf_calendar/.ssh' do
  owner 'kf_calendar'
  group 'kf_calendar'
  mode '700'
end

# <https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints>
GITHUB_SSH_KNOWN_HOSTS_ENTRY = 'github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl'
file '/etc/ssh/ssh_known_hosts'
file '/etc/ssh/ssh_known_hosts' do
  action :edit
  block do |content|
    unless content.each_line.any? {|l| l.chomp == GITHUB_SSH_KNOWN_HOSTS_ENTRY }
      content.concat("\n") unless content.empty? || content.end_with?("\n")
      content.concat(GITHUB_SSH_KNOWN_HOSTS_ENTRY)
      content.concat("\n")
    end
  end
end

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
remote_executable '/opt/kf-calendar/bin/calendar-update-feeds' do
  mode '755'
end

directory '/opt/kf-calendar/etc/systemd/system'
service_template '/opt/kf-calendar/etc/systemd/system/calendar-update-feeds.service'
service_file '/opt/kf-calendar/etc/systemd/system/calendar-update-feeds.timer'

service 'calendar-update-feeds.timer' do
  action :start
end
