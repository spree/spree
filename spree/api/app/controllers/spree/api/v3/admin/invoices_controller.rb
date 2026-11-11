module Spree
  module Api
    module V3
      module Admin
        # Every invoice in the store — what an accountant exports. Created
        # under the order or seller payout it belongs to; here it is read,
        # downloaded, sent again, or deleted while it is an unsent upload.
        class InvoicesController < ResourceController
          include Spree::Api::V3::InvoiceMemberActions

          scoped_resource :orders

          protected

          def serializer_class
            Spree.api.admin_invoice_serializer
          end

          # Commission invoices belong to seller payouts, so they follow the
          # payouts permission rather than the orders one this list needs.
          def scope
            holds_permission?('read_payouts') ? super : super.where(seller_payout_id: nil)
          end

          def authorize_resource!(resource = @resource, action = action_name.to_sym)
            super
            return unless resource.is_a?(Spree::Invoice) && resource.seller_payout_id

            permission = read_actions.include?(action.to_s) ? 'read_payouts' : 'write_payouts'
            raise CanCan::AccessDenied unless holds_permission?(permission)
          end
        end
      end
    end
  end
end
