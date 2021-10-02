module Spree
  module Api
    module V2
      module Platform
        class PaymentCaptureEventSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :payment
        end
      end
    end
  end
end
