module Spree
  module Api
    module V3
      module Storefront
        class CreditCardsController < ResourceController
          before_action :require_authentication!

          protected

          def scope
            current_user.credit_cards
          end

          def model_class
            Spree::CreditCard
          end

          def serializer_class
            Spree.api.v3_storefront_credit_card_serializer
          end
        end
      end
    end
  end
end
