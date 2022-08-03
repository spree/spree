module Spree
  module Api
    module V2
      module Platform
        class TranslatableResourceController < ResourceController
          def scope
            super.joins(:translations)
          end
        end
      end
    end
  end
end


