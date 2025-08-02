module Spree
  module Api
    module V2
      module Platform
        class PaymentCaptureEventSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :payment, serializer: Spree::Api::Dependencies.platform_payment_serializer.constantize
        end
      end
    end
  end
end
