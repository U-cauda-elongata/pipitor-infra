node.validate! do
  {
    mail: {
      from: string,
      user: string,
      password: string,
    },
  }
end

package 'msmtp'

user 'mail'

package 'msmtp'

template "#{node['user']['mail']['directory']}/.msmtprc" do
  source 'templates/home/mail/.msmtprc.erb'
  user 'mail'
  group 'mail'
  mode '600'
end
