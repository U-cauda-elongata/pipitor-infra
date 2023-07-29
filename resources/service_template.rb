module Itamae
  module Plugin
    module Resource
      class ServiceTemplate < Itamae::Resource::Template
        def pre_action
          super
          case @current_action
          when :create, :edit
            attributes.enabled = true
          when :delete
            attributes.enabled = false
          end
        end

        def set_current_attributes
          super
          current.enabled = run_specinfra(:check_service_is_enabled, attributes.path)
        end

        def action_create(options)
          super
          unless current.enabled
            name = attributes.path.split(File::SEPARATOR).last
            if run_specinfra(:check_service_is_enabled, name)
              run_specinfra(:disable_service, name)
            end
            run_specinfra(:enable_service, attributes.path)
          end
        end

        def action_delete(options)
          if current.enabled
            run_specinfra(:disable_service, attributes.path)
          end
          super
        end

        def action_edit(options)
          super
          if attributes.modified
            run_specinfra(:reload_service, attributes.path)
          end
        end
      end
    end
  end
end
