module Spree
  module Api
    module V3
      module Admin
        module Customers
          class CreditCardsController < BaseController
            protected

            def parent_association
              :credit_cards
            end

            def model_class
              Spree::CreditCard
            end

            def serializer_class
              Spree.api.admin_credit_card_serializer
            end
          end
        end
      end
    end
  end
end
