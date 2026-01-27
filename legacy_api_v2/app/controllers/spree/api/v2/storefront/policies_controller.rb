module Spree
  module Api
    module V2
      module Storefront
        class PoliciesController < ::Spree::Api::V2::ResourceController
          private

          def collection_serializer
            Spree.api.storefront_policy_serializer
          end

          def resource_serializer
            Spree.api.storefront_policy_serializer
          end

          def resource
            @resource ||= find_with_fallback_default_locale { scope.find_by(slug: params[:id]) } || scope.find(params[:id])
          end

          def model_class
            Spree::Policy
          end

          def scope_includes
            [:rich_text_translations]
          end
        end
      end
    end
  end
end
