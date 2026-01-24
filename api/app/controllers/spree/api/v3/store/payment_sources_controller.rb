module Spree
  module Api
    module V3
      module Store
        class PaymentSourcesController < Store::ResourceController
          prepend_before_action :require_authentication!

          protected

          def scope
            current_user.payment_sources
          end

          def model_class
            Spree::PaymentSource
          end

          def serializer_class
            Spree.api.payment_source_serializer
          end
        end
      end
    end
  end
end
