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

            # Customers are global; a saved card belongs to the store-scoped
            # payment method it was created against, so the nested collection is
            # bound to the current store's payment methods.
            def scope
              @parent.credit_cards.where(payment_method_id: current_store.payment_methods.select(:id))
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
