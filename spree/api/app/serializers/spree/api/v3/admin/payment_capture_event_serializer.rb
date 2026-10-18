module Spree
  module Api
    module V3
      module Admin
        # Serializes Spree::PaymentCaptureEvent — one capture of money a
        # payment had authorized. A payment captured in parts has one per part.
        class PaymentCaptureEventSerializer < V3::BaseSerializer
          attributes created_at: :iso8601, updated_at: :iso8601

          money_attributes :amount
          typelize amount: [:string, nullable: false]
        end
      end
    end
  end
end
