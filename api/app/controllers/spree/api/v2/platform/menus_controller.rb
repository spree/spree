module Spree
  module Api
    module V2
      module Platform
        class MenusController < ResourceController
          private

          def model_class
            Spree::Menu
          end

          def scope_includes
            [:menu_items]
          end
        end
      end
    end
  end
end
