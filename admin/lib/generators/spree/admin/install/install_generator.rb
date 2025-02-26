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
        end
      end
    end
  end
end
