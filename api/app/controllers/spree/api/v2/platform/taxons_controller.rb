module Spree
  module Api
    module V2
      module Platform
        class TaxonsController < ResourceController
          include ::Spree::Api::V2::Platform::NestedSetRepositionConcern

          private

          def model_class
            Spree::Taxon
          end

          def scope_includes
            node_includes = %i[icon parent taxonomy]

            {
              parent: node_includes,
              children: node_includes,
              taxonomy: [root: node_includes],
              icon: [attachment_attachment: :blob]
            }
          end

          def serializer_params
            super.merge(include_products: action_name == 'show')
          end

          def spree_permitted_attributes
            super + [:new_parent_id, :new_position_idx]
          end
        end
      end
    end
  end
end
