module Spree
  module Api
    module V3
      module Admin
        module Orders
          class PaymentsController < ResourceController
            include Spree::Api::V3::OrderLock

            before_action :authorize_order_access!
            skip_before_action :set_resource, only: [:index, :create]
            before_action :set_payment, only: [:show, :capture, :void]

            # POST /api/v3/admin/orders/:order_id/payments
            def create
              with_order_lock do
                payment_method = Spree::PaymentMethod.find(params[:payment_method_id])
                @resource = @parent.payments.build(
                  amount: params[:amount] || @parent.order_total_after_store_credit,
                  payment_method: payment_method
                )

                if params[:source_id].present? && payment_method.source_required?
                  @resource.source = payment_method.payment_source_class.find_by_prefix_id!(params[:source_id])
                end

                authorize_resource!(@resource, :create)

                if @resource.save
                  render json: serialize_resource(@resource), status: :created
                else
                  render_validation_error(@resource.errors)
                end
              end
            end

            # PATCH /api/v3/admin/orders/:order_id/payments/:id/capture
            def capture
              with_order_lock do
                amount = params[:amount] ? (params[:amount].to_f * 100).round : nil
                @resource.capture!(amount)
                render json: serialize_resource(@resource.reload)
              rescue Spree::Core::GatewayError => e
                render_service_error(e.message)
              end
            end

            # PATCH /api/v3/admin/orders/:order_id/payments/:id/void
            def void
              with_order_lock do
                @resource.void_transaction!
                render json: serialize_resource(@resource.reload)
              rescue Spree::Core::GatewayError => e
                render_service_error(e.message)
              end
            end

            protected

            def model_class
              Spree::Payment
            end

            def serializer_class
              Spree.api.admin_payment_serializer
            end

            def parent_association
              :payments
            end

            def set_parent
              @parent = current_store.orders.find_by_prefix_id!(params[:order_id])
              @order = @parent
            end

            def authorize_order_access!
              authorize!(:show, @parent)
            end

            def set_payment
              @resource = @parent.payments.find_by_prefix_id!(params[:id])
              authorize_resource!(@resource)
            end

            def permitted_params
              params.permit(:amount, :payment_method_id, :source_id)
            end

            private

            def render_result_error(result)
              error = result.error
              errors = error.respond_to?(:value) ? error.value : error

              if errors.is_a?(ActiveModel::Errors)
                render_validation_error(errors)
              else
                render_service_error(error)
              end
            end
          end
        end
      end
    end
  end
end
