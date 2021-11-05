module Spree
  module Api
    module V2
      module Platform
        class ZonesController < ResourceController
          private

          def model_class
            Spree::Zone
          end

          def scope_includes
            [:zone_members]
          end
        end
      end
    end
  end
end
