module Spree
  module Api
    module V3
      module Admin
        class AllowedOriginsController < ResourceController
          # A credential, not a setting: an allowed origin can read every
          # admin's session through the cookie-authenticated refresh endpoint,
          # so the list is managed under the same scope as API keys.
          scoped_resource :api_keys

          request_params :allowed_origin do |body|
            body.attribute :origin, :string,
              required: true, on: :create,
              example: 'https://admin.example.com',
              description: 'Origin to allow in admin CORS preflight checks: a bare `scheme://host[:port]` (no path, query or fragment) using `http` or `https`.'
          end

          protected

          def model_class
            Spree::AllowedOrigin
          end

          def serializer_class
            Spree.api.admin_allowed_origin_serializer
          end

          def permitted_params
            params.permit(*permitted_attributes)
          end
        end
      end
    end
  end
end
