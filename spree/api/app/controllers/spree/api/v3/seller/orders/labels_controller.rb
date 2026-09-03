module Spree
  module Api
    module V3
      module Seller
        module Orders
          # Labels on a parcel the seller ships themselves. Sellers fulfill on
          # manual methods only, so they upload a label bought elsewhere and
          # print it back — never purchase or refund, which need the
          # operator's carrier account.
          class LabelsController < Seller::BaseController
            include Spree::Api::V3::OrderLock
            include ActiveStorage::SetCurrent

            scoped_resource :fulfillments

            before_action :set_fulfillment
            before_action :set_label, only: [:show, :download, :destroy]

            rescue_from ActiveSupport::MessageVerifier::InvalidSignature, with: :render_invalid_signature

            def index
              render json: { data: @fulfillment.shipping_labels.map { |label| serialize(label) } }
            end

            def show
              render json: serialize(@label)
            end

            # POST /api/v3/seller/orders/:order_id/fulfillments/:fulfillment_id/labels
            #
            # Records an uploaded label; a request without a file is refused,
            # since purchase is the operator's.
            def create
              authorize! :update, @fulfillment

              if label_params[:file].blank?
                return render_error(
                  code: ERROR_CODES[:validation_error],
                  message: Spree.t('shipping_labels.errors.file_required'),
                  status: :unprocessable_content
                )
              end

              with_order_lock do
                result = Spree.shipping_label_record_workflow.call(
                  owner: @fulfillment,
                  file: label_params[:file],
                  tracking_number: label_params[:tracking_number],
                  carrier: label_params[:carrier],
                  service: label_params[:service],
                  cost: label_params[:cost],
                  currency: label_params[:currency],
                  file_format: label_params[:file_format],
                  tracking_url: label_params[:tracking_url]
                )

                if result.success?
                  render json: serialize(result.value), status: :created
                else
                  render_result_error(result)
                end
              end
            end

            # GET .../labels/:id/download
            def download
              if @label.file.attached?
                send_data(
                  @label.file.download,
                  filename: @label.download_filename,
                  type: @label.file.content_type || 'application/octet-stream',
                  disposition: 'attachment'
                )
              elsif @label.file_pending?
                redirect_to @label.file_url, allow_other_host: true
              else
                render_error(
                  code: ERROR_CODES[:validation_error],
                  message: Spree.t('shipping_labels.errors.no_file_url'),
                  status: :unprocessable_content
                )
              end
            end

            # DELETE .../labels/:id — uploaded labels only.
            def destroy
              authorize! :update, @fulfillment

              unless @label.uploaded?
                return render_error(
                  code: ERROR_CODES[:validation_error],
                  message: Spree.t('shipping_labels.errors.purchased_not_deletable'),
                  status: :unprocessable_content
                )
              end

              with_order_lock do
                ApplicationRecord.transaction do
                  @label.delivery&.destroy!
                  @label.destroy!
                end
                head :no_content
              end
            end

            protected

            def read_actions
              %w[index show download]
            end

            private

            def set_fulfillment
              @order = current_seller_orders.find_by_prefix_id!(params[:order_id])
              authorize! :show, @order
              @fulfillment = @order.fulfillments.find_by_prefix_id!(params[:fulfillment_id])
            end

            def set_label
              @label = @fulfillment.shipping_labels.find_by_prefix_id!(params[:id])
            end

            def label_params
              @label_params ||= params.permit(:file, :tracking_number, :carrier, :service, :cost, :currency, :file_format, :tracking_url)
            end

            def serialize(label)
              Spree.api.seller_shipping_label_serializer.new(label, params: { store: current_store }).to_h
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
