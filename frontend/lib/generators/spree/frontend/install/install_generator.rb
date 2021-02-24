module Spree
  module Frontend
    module Generators
      class InstallGenerator < Rails::Generators::Base
        desc 'Copies storefront configuration files for easy customization'

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
          # main navigation configuration
          template 'config/initializers/spree_storefront.rb', 'config/initializers/spree_storefront.rb'
          template 'config/spree_storefront.yml', 'config/spree_storefront.yml'
          # static images
          directory 'noimage', './app/assets/images/noimage'
          directory 'homepage', './app/assets/images/homepage'
          directory 'meganav', './app/assets/images/meganav'
          # SCSS theming
          template 'variables.scss', './app/assets/stylesheets/spree/frontend/variables/variables.scss'
          # home page template
          directory 'home', './app/views/spree/home'
        end
      end
    end
  end
end
