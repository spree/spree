module Spree
  module Api
    module V3
      module Admin
        module Orders
          class PaymentsController < BaseController
            before_action :set_resource, only: [:show, :capture, :void]

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

            def permitted_params
              params.permit(*Spree::PermittedAttributes.payment_attributes, :source_id)
            end
          end
        end
      end
    end
  end
end
