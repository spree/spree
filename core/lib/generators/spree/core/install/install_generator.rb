module Spree
  module Core
    module Generators
      class InstallGenerator < Rails::Generators::Base
        desc 'Installs Spree Welcome Page'

        def self.source_paths
          [
            File.expand_path('templates', __dir__),
            File.expand_path('../templates', "../#{__FILE__}"),
            File.expand_path('../templates', "../../#{__FILE__}")
          ]
        end

        def install
          template 'vendor/assets/javascripts/spree/core/all.js'
          template 'vendor/assets/stylesheets/spree/core/all.css'
        end
      end
    end
  end
end
