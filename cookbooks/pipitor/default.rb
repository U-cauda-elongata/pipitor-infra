node.validate! do
  {
    pipitor: {
      twitter: {
        key: string,
        secret: string,
      },
      # XXX: This map is mandated because the underlying library doesn't allow optional maps.
      # cf. <https://github.com/ryotarai/schash/pull/5>
      websub: {
        host: string,
      },
    },
  }
end

package 'ca-certificates'
package 'sqlite3'

user 'pipitor'

extract_http_archive '/usr/local/bin/pipitor' do
  version = '0.3.0-alpha.9.4'
  url "https://github.com/tesaguri/pipitor/releases/download/v#{version}/pipitor-v#{version}-#{node['triple']}.tar.gz"
  checksum({
    'aarch64-unknown-linux-gnu' => '4b8bf6454cc48ddd6eab4a8224ad42d5ef4c7689e7e9f84fbfc9d7b648963de8',
    'x86_64-unknown-linux-gnu' => 'd9268c145e0dd59facc98708fc391ce1631a4bb90ebcac8d59a3e038b6b7a1f3',
  }[node['triple']])
  path_in_archive 'pipitor'
  mode '755'
end

directory '/opt/pipitor-infra/share'
directory '/opt/pipitor-infra/share/pipitor' do
  owner 'pipitor'
  group 'pipitor'
end
git '/opt/pipitor-infra/share/pipitor' do
  repository 'https://github.com/U-cauda-elongata/KF_pipitor-resources.git'
  user 'pipitor'
end
template '/opt/pipitor-infra/share/pipitor/credentials.toml' do
  owner 'pipitor'
  group 'pipitor'
  mode '600'
end

directory '/opt/pipitor-infra/etc/systemd/system'
service_file '/opt/pipitor-infra/etc/systemd/system/pipitor.socket'
service_file '/opt/pipitor-infra/etc/systemd/system/pipitor.service'

service 'pipitor' do
  action :start
end

service_file '/opt/pipitor-infra/etc/systemd/system/pipitor-websub-proxy.socket'
service_file '/opt/pipitor-infra/etc/systemd/system/pipitor-websub-proxy.service'

service 'pipitor-websub-proxy' do
  action :start
end

directory '/opt/pipitor-infra/bin'
remote_file '/opt/pipitor-infra/bin/pipitor-renew-subs' do
  mode '755'
end
service_file '/opt/pipitor-infra/etc/systemd/system/pipitor-renew-subs.service'
service_file '/opt/pipitor-infra/etc/systemd/system/pipitor-renew-subs.timer'

service 'pipitor-renew-subs.timer' do
  action :start
end

directory '/opt/pipitor-infra/etc/nginx/default.d'
remote_file '/opt/pipitor-infra/etc/nginx/default.d/pipitor.conf'
directory '/etc/nginx/default.d'
link '/etc/nginx/default.d/pipitor.conf' do
  to '/opt/pipitor-infra/etc/nginx/default.d/pipitor.conf'
end
