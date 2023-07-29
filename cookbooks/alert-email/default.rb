node.validate! do
  {
    alert_email: {
      recipient: string,
      from: string,
      user: string,
      password: string,
    },
  }
end

package 'msmtp'

template "#{node['user']['pipitor']['directory']}/.msmtprc" do
  source 'templates/home/pipitor/.msmtprc.erb'
  user 'pipitor'
  group 'pipitor'
  mode '600'
end

template '/etc/systemd/system/alert-email@.service'
