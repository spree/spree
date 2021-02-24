module Spree
  module Frontend
    class CopyStorefrontGenerator < Rails::Generators::Base
      desc 'Copies all storefront views and stylesheets from spree frontend to your application'

      def self.source_paths
        [
          File.expand_path('../../../../../app', __dir__),
          File.expand_path('../../../../../app/assets/stylesheets/spree/frontend', __dir__),
        ]
      end

      def copy_storefront
        directory 'views', './app/views'
        template 'application.scss', './app/assets/stylesheets/spree/frontend/application.scss'
      end
    end
  end
end
