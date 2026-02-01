module Spree
  module Api
    module V3
      module Store
        module Customer
          class CreditCardsController < ResourceController
            prepend_before_action :require_authentication!

            protected

            def set_parent
              @parent = current_user
            end

            def parent_association
              :credit_cards
            end

            def model_class
              Spree::CreditCard
            end

            def serializer_class
              Spree.api.credit_card_serializer
            end
          end
        end
      end
    end
  end
end
