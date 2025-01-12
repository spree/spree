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
        end
      end
    end
  end
end
