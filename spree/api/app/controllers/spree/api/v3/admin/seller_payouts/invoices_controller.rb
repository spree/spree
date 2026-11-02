module Spree
  module Api
    module V3
      module Admin
        module SellerPayouts
          # Commission invoices the marketplace issued the seller for one
          # payout, uploaded from the operator's accounting system.
          class InvoicesController < Admin::ResourceController
            include Spree::Api::V3::Orders::InvoiceUpload

            scoped_resource :payouts

            before_action :authorize_payout_access!

            protected

            def set_parent
              @parent = Spree::SellerPayout.for_store(current_store).find_by_prefix_id!(params[:seller_payout_id])
            end

            def authorize_payout_access!
              authorize_parent!(@parent)
            end

            # A commission invoice is payout paperwork: updating the payout,
            # already checked above, is the permission it needs, not the
            # orders one that `Spree::Invoice` sits under.
            def authorize_resource!(resource = @resource, action = action_name.to_sym)
              action == :create ? authorize!(:update, @parent) : super
            end

            def serializer_class
              Spree.api.admin_invoice_serializer
            end
          end
        end
      end
    end
  end
end
