module Spree
  module Api
    module V2
      module Platform
        class GiftCardsController < ResourceController
          private

          def model_class
            Spree::GiftCard
          end
        end
      end
    end
  end
end
