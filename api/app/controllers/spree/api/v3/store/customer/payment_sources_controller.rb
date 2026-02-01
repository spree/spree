module Spree
  module Api
    module V3
      module Store
        module Customer
          class PaymentSourcesController < ResourceController
            prepend_before_action :require_authentication!

            protected

            def set_parent
              @parent = current_user
            end

            def parent_association
              :wallet_payment_sources
            end

            def model_class
              Spree::WalletPaymentSource
            end

            def serializer_class
              Spree.api.wallet_payment_source_serializer
            end
          end
        end
      end
    end
  end
end
