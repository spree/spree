module Spree
  module Api
    module V2
      module Platform
        class WishedItemsController < ResourceController
          private

          def scope_includes
            [:variant]
          end

          def model_class
            Spree::WishedItem
          end

          def resource_serializer
            Spree.api.platform_wished_item_serializer
          end
        end
      end
    end
  end
end
