module Spree
  module Api
    module V3
      module Store
        module Checkout
          class PaymentsController < Store::ResourceController
            include Spree::Api::V3::CartResolvable

            # POST /api/v3/store/checkout/payments
            # Creates a payment for non-session payment methods (e.g. Check, Cash on Delivery, Bank Transfer)
            def create
              payment_method = current_store.payment_methods.find_by_prefix_id!(params[:payment_method_id])

              if payment_method.session_required?
                return render_error(
                  code: 'payment_session_required',
                  message: Spree.t('api.v3.payments.session_required'),
                  status: :unprocessable_content
                )
              end

              unless payment_method.available_for_order?(@parent)
                return render_error(
                  code: 'payment_method_unavailable',
                  message: Spree.t('api.v3.payments.method_unavailable'),
                  status: :unprocessable_content
                )
              end

              amount = params[:amount].presence || @parent.total_minus_store_credits

              @payment = @parent.payments.build(
                payment_method: payment_method,
                amount: amount,
                metadata: params[:metadata].present? ? params[:metadata].to_unsafe_h : {}
              )

              if @payment.save
                render json: serialize_resource(@payment), status: :created
              else
                render_errors(@payment.errors)
              end
            end

            protected

            def set_parent
              find_cart!
              @parent = @cart
            end

            def parent_association
              :payments
            end

            def model_class
              Spree::Payment
            end

            def serializer_class
              Spree.api.payment_serializer
            end

            # Authorization is handled by find_cart! in set_parent
            def authorize_resource!(*)
            end
          end
        end
      end
    end
  end
end
