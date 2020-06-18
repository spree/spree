module Spree
  module Frontend
    class CopyStorefrontGenerator < Rails::Generators::Base
      desc 'Copies storefront from spree frontend to your application'

      def self.source_paths
        [
          File.expand_path('../../../../../app', __dir__),
          File.expand_path('../../../../../app/assets/images', __dir__),
          File.expand_path('../../../../../app/assets/stylesheets/spree/frontend', __dir__),
          File.expand_path('../../../../../app/assets/stylesheets/spree/frontend/variables', __dir__)
        ]
      end

      def copy_storefront
        directory 'views', './app/views'
        directory 'noimage', './app/assets/images/noimage'
        directory 'homepage', './app/assets/images/homepage'
        directory 'meganav', './app/assets/images/meganav'
        template 'application.scss', './app/assets/stylesheets/spree/frontend/application.scss'
        template 'variables.scss', './app/assets/stylesheets/spree/frontend/variables/variables.scss'
      end
    end
  end
end
