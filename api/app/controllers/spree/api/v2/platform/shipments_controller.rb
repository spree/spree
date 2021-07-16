module Spree
  module Api
    module V2
      module Platform
        class ShipmentsController < ResourceController
          def model_class
            Spree::Shipment
          end

          def scope_includes
            [:line_items]
          end
        end
      end
    end
  end
end
