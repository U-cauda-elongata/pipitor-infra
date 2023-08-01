require 'spec_helper'

describe command('/usr/local/bin/pipitor --version') do
  its(:stdout) { should match(/^pipitor /) }
end
