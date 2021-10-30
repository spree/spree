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
        end
      end
    end
  end
end
