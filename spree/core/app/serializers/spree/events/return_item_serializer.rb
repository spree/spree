# frozen_string_literal: true

module Spree
  module Events
    class ReturnItemSerializer < BaseSerializer
      protected

      def attributes
        {
          id: public_id(resource),
          reception_status: resource.reception_status,
          acceptance_status: resource.acceptance_status,
          pre_tax_amount: money(resource.pre_tax_amount),
          included_tax_total: money(resource.included_tax_total),
          additional_tax_total: money(resource.additional_tax_total),
          inventory_unit_id: public_id(resource.inventory_unit),
          return_authorization_id: public_id(resource.return_authorization),
          customer_return_id: public_id(resource.customer_return),
          reimbursement_id: public_id(resource.reimbursement),
          exchange_variant_id: public_id(resource.exchange_variant),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
