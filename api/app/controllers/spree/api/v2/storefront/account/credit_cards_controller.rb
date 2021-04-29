module Spree
  module Api
    module V2
      module Storefront
        module Account
          class CreditCardsController < ::Spree::Api::V2::ResourceController
            before_action :require_spree_current_user

            private

            def model_class
              Spree::CreditCard
            end

            def scope
              super.where(user: spree_current_user)
            end

            def collection_serializer
              Spree::Api::Dependencies.storefront_credit_card_serializer.constantize
            end

            def collection_finder
              Spree::Api::Dependencies.storefront_credit_card_finder.constantize
            end

            def resource_serializer
              Spree::Api::Dependencies.storefront_credit_card_serializer.constantize
            end

            def resource_finder
              Spree::Api::Dependencies.storefront_credit_card_finder.constantize
            end
          end
        end
      end
    end
  end
end
