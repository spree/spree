module Spree
  module Api
    module V3
      module Admin
        module Orders
          # Shipping labels on one parcel — a fulfillment's outbound label
          # under /orders/:order_id/fulfillments/:fulfillment_id/labels, a
          # return's inbound label under /orders/:order_id/returns/:return_id/labels
          # (docs/plans/6.0-shipping-labels-and-deliveries.md).
          #
          # Creating one either buys it through the parcel's provider, or —
          # when a +file+ is given — records a label the merchant bought
          # elsewhere. A refund is a transition, so it is a PATCH member
          # action; the only destroy is for an uploaded label, which has
          # nothing to refund.
          class LabelsController < BaseController
            include ActiveStorage::SetCurrent

            before_action :set_resource, only: [:show, :download, :refund, :destroy]

            # A tampered signed id would otherwise surface as a 500.
            rescue_from ActiveSupport::MessageVerifier::InvalidSignature, with: :render_invalid_signature

            # POST .../labels
            def create
              authorize!(:create, Spree::ShippingLabel)

              with_order_lock do
                result = if label_params[:file].present?
                           Spree.shipping_label_record_workflow.call(owner: @parent, **record_arguments)
                         else
                           Spree.shipping_label_purchase_workflow.call(owner: @parent)
                         end

                if result.success?
                  render json: serialize_resource(result.value), status: :created
                else
                  render_result_error(result)
                end
              end
            end

            # GET .../labels/:id/download — streamed rather than redirected, so
            # the label is never reachable without admin credentials. The
            # carrier's copy is proxied only while the fetch is still pending.
            def download
              if @resource.file.attached?
                send_data(
                  @resource.file.download,
                  filename: @resource.download_filename,
                  type: @resource.file.content_type || 'application/octet-stream',
                  disposition: 'attachment'
                )
              elsif @resource.file_pending?
                redirect_to @resource.file_url, allow_other_host: true
              else
                render_error(
                  code: ERROR_CODES[:validation_error],
                  message: Spree.t('shipping_labels.errors.no_file_url'),
                  status: :unprocessable_content
                )
              end
            end

            # PATCH .../labels/:id/refund
            def refund
              with_order_lock do
                result = Spree.shipping_label_refund_workflow.call(shipping_label: @resource)

                if result.success?
                  render json: serialize_resource(result.value)
                else
                  render_result_error(result)
                end
              end
            end

            # DELETE .../labels/:id — uploaded labels only; a purchased label
            # is refunded, never deleted, so the postage history stays honest.
            def destroy
              unless @resource.uploaded?
                return render_error(
                  code: ERROR_CODES[:validation_error],
                  message: Spree.t('shipping_labels.errors.purchased_not_deletable'),
                  status: :unprocessable_content
                )
              end

              with_order_lock do
                ApplicationRecord.transaction do
                  @resource.delivery&.destroy!
                  @resource.destroy!
                end
                head :no_content
              end
            end

            protected

            def model_class
              Spree::ShippingLabel
            end

            def serializer_class
              Spree.api.admin_shipping_label_serializer
            end

            def parent_association
              :shipping_labels
            end

            def collection_includes
              [:integration, :delivery, { file_attachment: :blob }]
            end

            # The owner — fulfillment or return — is the parent the labels hang
            # off; the order is fetched first so an owner id from another
            # order can never resolve.
            def set_parent
              @order = current_store.orders.find_by_prefix_id!(params[:order_id])
              @parent = if params[:return_id].present?
                          @order.returns.find_by_prefix_id!(params[:return_id])
                        else
                          @order.fulfillments.find_by_prefix_id!(params[:fulfillment_id])
                        end
            end

            READ_ACTIONS = %w[index show download].freeze

            def read_actions
              READ_ACTIONS
            end

            def label_params
              @label_params ||= params.permit(:file, :tracking_number, :carrier, :service, :cost, :currency, :file_format, :tracking_url)
            end

            def record_arguments
              {
                file: label_params[:file],
                tracking_number: label_params[:tracking_number],
                carrier: label_params[:carrier],
                service: label_params[:service],
                cost: label_params[:cost],
                currency: label_params[:currency],
                file_format: label_params[:file_format],
                tracking_url: label_params[:tracking_url]
              }
            end

            def render_invalid_signature
              render_error(code: ERROR_CODES[:parameter_invalid], message: Spree.t('shipping_labels.errors.file_required'), status: :unprocessable_content)
            end
          end
        end
      end
    end
  end
end
