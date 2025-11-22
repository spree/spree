require 'rails/generators'

module Spree
  module Storefront
    module Generators
      class ThemeGenerator < Rails::Generators::Base
        argument :name, type: :string, default: 'my_theme'

        def self.source_paths
          [
            File.expand_path('templates', __dir__),
            File.expand_path('../../../../../app/views', __dir__)
          ]
        end

        def copy_theme
          empty_directory "app/models/spree/themes"
          template "model.rb.tt", "app/models/spree/themes/#{file_name}.rb"

          empty_directory "app/views/themes"

          directory "themes/default", "app/views/themes/#{file_name}"

          append_to_file "config/initializers/spree.rb", after: "Rails.application.config.after_initialize do\n" do
            "  Spree.page_builder.themes << Spree::Themes::#{class_name}\n"
          end
        end

        no_tasks do
          def class_name
            name.camelize
          end

          def file_name
            name.underscore
          end
        end
      end
    end
  end
end
