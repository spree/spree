# frozen_string_literal: true

module Spree
  module Events
    class ReturnItemSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.prefix_id,
          reception_status: resource.reception_status,
          acceptance_status: resource.acceptance_status,
          pre_tax_amount: money(resource.pre_tax_amount),
          included_tax_total: money(resource.included_tax_total),
          additional_tax_total: money(resource.additional_tax_total),
          inventory_unit_id: association_prefix_id(:inventory_unit),
          return_authorization_id: association_prefix_id(:return_authorization),
          customer_return_id: association_prefix_id(:customer_return),
          reimbursement_id: association_prefix_id(:reimbursement),
          exchange_variant_id: association_prefix_id(:exchange_variant),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
