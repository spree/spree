module Spree
  module Api
    module V3
      module Admin
        class VariantsController < ResourceController
          scoped_resource :products

          protected

          def model_class
            Spree::Variant
          end

          def serializer_class
            Spree.api.admin_variant_serializer
          end

          def scope
            current_store.variants.eligible.accessible_by(current_ability, ability_action_for_request)
          end

          def scope_includes
            [
              :prices, stock_items: :stock_location,
              option_values: :option_type,
              primary_media: [attachment_attachment: :blob]
            ]
          end
        end
      end
    end
  end
end
