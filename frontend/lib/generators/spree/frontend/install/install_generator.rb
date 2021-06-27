module Spree
  module Frontend
    module Generators
      class InstallGenerator < Rails::Generators::Base
        desc 'Installs Spree rails storefront'

        def self.source_paths
          [
            File.expand_path('templates', __dir__),
            File.expand_path('../templates', "../#{__FILE__}"),
            File.expand_path('../templates', "../../#{__FILE__}"),
            File.expand_path('../../../../../app/views/spree', __dir__),
            File.expand_path('../../../../../app/assets/images', __dir__),
            File.expand_path('../../../../../app/assets/stylesheets/spree/frontend/variables', __dir__)
          ]
        end

        def install
          template 'vendor/assets/javascripts/spree/frontend/all.js'
          template 'vendor/assets/stylesheets/spree/frontend/all.css'
          # static images
          directory 'noimage', './app/assets/images/noimage'
          directory 'homepage', './app/assets/images/homepage'
          # SCSS theming
          template 'variables.scss', './app/assets/stylesheets/spree/frontend/variables/variables.scss'
          # Sprockets 4 manifest
          template 'app/assets/config/manifest.js'
          # home page template
          directory 'home', './app/views/spree/home'
        end
      end
    end
  end
end
