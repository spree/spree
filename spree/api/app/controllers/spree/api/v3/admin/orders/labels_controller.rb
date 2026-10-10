module Spree
  module Api
    module V3
      module Admin
        module Orders
          # The postage on a parcel or a return.
          #
          # Recording, printing and deleting live in the shared concern. What
          # is here is what needs the operator's carrier account: buying a
          # label, and refunding one that was bought and not used.
          class LabelsController < BaseController
            include Spree::Api::V3::Orders::ShippingLabelActions

            before_action :set_resource, only: [:show, :download, :refund, :destroy]

            # POST .../labels
            #
            # Buys the label through the parcel's provider, or — when a `file_signed_id`
            # is given — records one the merchant bought elsewhere.
            def create
              authorize!(:create, Spree::ShippingLabel)

              return record_uploaded_label if label_params[:file_signed_id].present?

              with_order_lock do
                result = Spree.shipping_label_purchase_workflow.call(owner: @parent)

                render_result(result, status: :created)
              end
            end

            # PATCH .../labels/:id/refund — a transition, so a member action.
            def refund
              with_order_lock do
                result = Spree.shipping_label_refund_workflow.call(shipping_label: @resource)

                render_result(result)
              end
            end

            protected

            def serializer_class
              Spree.api.admin_shipping_label_serializer
            end

            def collection_includes
              [:integration, :delivery, { file_attachment: :blob }]
            end

            # The owner — fulfillment or return — is the parent the labels
            # hang off; the base fetches the order first, so an owner id from
            # another order can never resolve.
            def set_parent
              super
              @parent = if params[:return_id].present?
                          @order.returns.find_by_prefix_id!(params[:return_id])
                        else
                          @order.fulfillments.find_by_prefix_id!(params[:fulfillment_id])
                        end
            end
          end
        end
      end
    end
  end
end
