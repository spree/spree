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
          empty_directory Rails.root.join('app/assets/tailwind') if Rails.root && !Rails.root.join('app/assets/tailwind').exist?
          template 'application.css', 'app/assets/tailwind/application.css'
          template 'tailwind.config.js', 'config/tailwind.config.js'

          if Rails.root && Rails.root.join("Procfile.dev").exist?
            append_to_file 'Procfile.dev', "\nstorefront_css: bin/rails tailwindcss:watch" unless File.read('Procfile.dev').include?('storefront_css:')
          else
            create_file 'Procfile.dev', "storefront_css: bin/rails tailwindcss:watch\n"
          end

          say "Add bin/dev to start foreman"
          copy_file "dev", "bin/dev", force: true
          chmod "bin/dev", 0755, verbose: false

          empty_directory Rails.root.join('app/assets/builds') if Rails.root

          unless File.exist?('app/assets/config/manifest.js')
            create_file 'app/assets/config/manifest.js', "//= link_tree ../builds\n"

            say "Ensure foreman is installed"
            run "gem install foreman"
          else
            append_to_file 'app/assets/config/manifest.js', "\n//= link_tree ../builds" unless File.read('app/assets/config/manifest.js').include?('//= link_tree ../builds')
          end

          # remove static robots.txt as we use robots.txt.erb
          remove_file Rails.root.join('public/robots.txt') if Rails.root && Rails.root.join('public/robots.txt').exist?
        end
      end
    end
  end
end
