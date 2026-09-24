module Spree
  module Api
    module V3
      module Store
        module Carts
          class PaymentsController < Store::BaseController
            include Spree::Api::V3::CartResolvable

            before_action :find_cart!

            # POST /api/v3/store/carts/:cart_id/payments
            # Creates a payment for non-session payment methods (e.g. Check, Cash on Delivery, Bank Transfer)
            def create
              # The same methods the cart offers: a disabled or staff-only
              # method (an offline one marks the order paid) must not be
              # reachable by naming its id.
              payment_method = current_store.payment_methods.active.storefront_visible.
                               find_by_prefix_id!(params[:payment_method_id])

              if payment_method.session_required?
                return render_error(
                  code: 'payment_session_required',
                  message: Spree.t('api.v3.payments.session_required'),
                  status: :unprocessable_content
                )
              end

              # Store credit passes the lookup above but has its own endpoint, so
              # it is never among the methods the cart offers.
              unless @cart.payment_methods.include?(payment_method)
                return render_error(
                  code: 'payment_method_unavailable',
                  message: Spree.t('api.v3.payments.method_unavailable'),
                  status: :unprocessable_content
                )
              end

              amount = params[:amount].presence || @cart.total_minus_store_credits

              @payment = @cart.payments.build(
                payment_method: payment_method,
                amount: amount,
                metadata: params[:metadata].present? ? params[:metadata].to_unsafe_h : {}
              )

              if @payment.save
                render json: Spree.api.payment_serializer.new(@payment, params: serializer_params).to_h, status: :created
              else
                render_errors(@payment.errors)
              end
            end
          end
        end
      end
    end
  end
end
