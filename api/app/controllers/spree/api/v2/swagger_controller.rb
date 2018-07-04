module Spree
  module Api
    module V2
      class SwaggerController < ActionController::API
        def storefront
          file_path = File.expand_path('../../../../../../docs/v2/storefront/index.yaml', __FILE__)
          send_file File.open(file_path), type: 'application/x-yaml'
        end
      end
    end
  end
end
