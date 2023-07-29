node.validate! do
  {
    webhook: {
      secret: string,
    },
  }
end

package 'gnupg2'
package 'jq'

extract_http_archive '/usr/local/bin/webhook-server' do
  version = '0.1.0'
  url "https://github.com/tesaguri/webhook-server/releases/download/v#{version}/webhook-server-v#{version}-#{node['triple']}.tar.gz"
  checksum({
    'aarch64-unknown-linux-gnu': 'c0a959c959297bcf586d59fc92005c407c9370178ba45838dd14fc91f45148ed',
    'x86_64-unknown-linux-gnu': '1b2835d57d57696d08ee95227ef29620086fccfa0dd847368aac9535db2bcb02',
  }[node['triple']])
  path_in_archive 'webhook-server'
  mode '755'
end

directory '/opt/pipitor-infra/bin'
remote_file '/opt/pipitor-infra/bin/pipitor-ci-webhook' do
  mode '755'
end

directory '/opt/pipitor-infra/share/webhook'
template '/opt/pipitor-infra/share/webhook/webhook.toml'

directory '/opt/pipitor-infra/etc/systemd/system'
service_file '/opt/pipitor-infra/etc/systemd/system/webhook.socket'
service_file '/opt/pipitor-infra/etc/systemd/system/webhook.service'

directory '/opt/pipitor-infra/etc/nginx/default.d'
remote_file '/opt/pipitor-infra/etc/nginx/default.d/webhook.conf'
directory '/etc/nginx/default.d'
link '/etc/nginx/default.d/webhook.conf' do
  to '/opt/pipitor-infra/etc/nginx/default.d/webhook.conf'
end

service 'webhook' do
  action :start
end
