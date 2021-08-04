module Spree
  module Api
    module V2
      module Platform
        class TaxonsController < ResourceController
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
        end
      end
    end
  end
end
