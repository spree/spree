module Spree
  module Api
    module V2
      module Platform
        class StatesController < ResourceController
          private

          def model_class
            Spree::State
          end

          def scope_includes
            [:country]
          end
        end
      end
    end
  end
end
