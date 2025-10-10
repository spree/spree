module Spree
  module Api
    module V2
      module Platform
        class GiftCardsController < ResourceController
          private

          def model_class
            Spree::GiftCard
          end

          def permitted_resource_params
            params.require(:gift_card).permit(permitted_gift_card_attributes)
          end

          def resource_serializer
            Spree::Api::Dependencies.platform_gift_card_serializer.constantize
          end
        end
      end
    end
  end
end
