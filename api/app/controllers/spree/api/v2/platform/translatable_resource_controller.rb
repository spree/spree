module Spree
  module Api
    module V2
      module Platform
        class TranslatableResourceController < ResourceController

          def scope
            base_scope = super
            base_scope = base_scope.joins(:translations)
            base_scope
          end
        end
      end
    end
  end
end


