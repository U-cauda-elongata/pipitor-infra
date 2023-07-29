require_relative 'resources/extract_http_archive'
require_relative 'resources/service_file'
require_relative 'resources/service_template'

os = node['kernel']['name']
vendor_os = case os
when 'Linux'
  'unknown-linux-gnu'
else
  raise StandardError, "Unknown OS: #{os}"
end
node['triple'] = "#{node['kernel']['machine']}-#{vendor_os}"

user 'pipitor'

include_recipe 'cookbooks/alert-email'
include_recipe 'cookbooks/pipitor'
include_recipe 'cookbooks/webhook'
include_recipe 'cookbooks/nginx'
include_recipe 'cookbooks/calendar'
