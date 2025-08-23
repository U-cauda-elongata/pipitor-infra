module Itamae
  module Plugin
    module Resource
      class RemoteExecutable < Itamae::Resource::RemoteFile
        def action_create(options)
          super
          if check_command('command -v restorecon')
            run_command("restorecon #{shell_escape(attributes.path)}")
          end
        end
      end
    end
  end
end
