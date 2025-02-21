require 'rails/generators'

module Spree
  module Storefront
    module Generators
      class InstallGenerator < Rails::Generators::Base
        desc 'Installs Spree Storefront'

        def self.source_paths
          [
            File.expand_path('templates', __dir__),
            File.expand_path('../templates', "../#{__FILE__}"),
            File.expand_path('../templates', "../../#{__FILE__}")
          ]
        end

        def install
          template 'application.tailwind.css', 'app/assets/stylesheets/application.tailwind.css'
          template 'tailwind.config.js', 'config/tailwind.config.js'

          unless File.exist?('Procfile.dev')
            create_file 'Procfile.dev', "storefront_css: bin/rails tailwindcss:watch\n"
          else
            append_to_file 'Procfile.dev', "\nstorefront_css: bin/rails tailwindcss:watch" unless File.read('Procfile.dev').include?('storefront_css:')
          end
        end
      end
    end
  end
end
