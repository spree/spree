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
            node_includes = %i[icon products parent taxonomy]

            {
              parent: node_includes,
              children: node_includes,
              taxonomy: [root: node_includes],
              products: [],
              icon: [attachment_attachment: :blob]
            }
          end
        end
      end
    end
  end
end
