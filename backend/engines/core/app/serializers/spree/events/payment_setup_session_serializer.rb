# frozen_string_literal: true

module Spree
  module Events
    class PaymentSetupSessionSerializer < BaseSerializer
      protected

      def attributes
        {
          id: public_id(resource),
          status: resource.status.to_s,
          external_id: resource.external_id,
          payment_method_id: public_id(resource.payment_method),
          customer_id: public_id(resource.customer),
          payment_source_id: public_id(resource.payment_source),
          payment_source_type: resource.payment_source_type,
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
