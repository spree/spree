module Spree
  module Api
    module V2
      module Platform
        class DigitalLinksController < ResourceController
          private

          def model_class
            Spree::DigitalLink
          end
        end
      end
    end
  end
end
