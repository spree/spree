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

          # Chains onto the base scope rather than replacing it: building the
          # relation from scratch dropped `scope_includes`, so every listed
          # variant fell back to per-row price and stock queries.
          def scope
            super.eligible.accessible_by(current_ability, ability_action_for_request)
          end

          # `active_stock_reservations` rides along with the stock levels:
          # without it the quantifier falls back to a SUM per variant, which
          # is the whole cost of listing variants.
          def scope_includes
            [
              :prices,
              { stock_levels: [:stock_location, :active_stock_reservations] },
              { option_values: :option_type },
              { primary_media: [{ attachment_attachment: :blob }, { poster_attachment: :blob }] }
            ]
          end
        end
      end
    end
  end
end
