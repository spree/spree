require 'rails/generators'

module Spree
  module Admin
    module Generators
      class InstallGenerator < Rails::Generators::Base
        desc 'Installs Spree Admin Dashboard'

        def self.source_paths
          [
            File.expand_path('templates', __dir__),
            File.expand_path('../templates', "../#{__FILE__}"),
            File.expand_path('../templates', "../../#{__FILE__}")
          ]
        end

        def install
          if Rails.root && Rails.root.join("Procfile.dev").exist?
            # Remove old dartsass entry if present
            if File.read('Procfile.dev').include?('dartsass:watch')
              gsub_file 'Procfile.dev', /^admin_css:.*dartsass:watch.*\n?/, ''
            end
            append_to_file 'Procfile.dev', "\nadmin_css: bin/rails spree:admin:tailwindcss:watch" unless File.read('Procfile.dev').include?('spree:admin:tailwindcss:watch')
          else
            create_file 'Procfile.dev', "admin_css: bin/rails spree:admin:tailwindcss:watch\n"
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
        end
      end
    end
  end
end
