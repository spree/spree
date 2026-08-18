module Spree
  module Api
    module V3
      module Store
        module Carts
          class PaymentSessionsController < Store::BaseController
            include Spree::Api::V3::CartResolvable
            include Spree::Api::V3::OrderLock

            before_action :find_cart!
            before_action :set_payment_session, only: [:show, :update, :complete]

            # POST /api/v3/store/carts/:cart_id/payment_sessions
            def create
              with_order_lock do
                payment_method = current_store.payment_methods.find_by_prefix_id!(permitted_params[:payment_method_id])

                @payment_session = payment_method.create_payment_session(
                  order: @cart,
                  amount: permitted_params[:amount],
                  external_data: permitted_params[:external_data] || {}
                )

                if @payment_session.persisted?
                  render json: serialize_resource(@payment_session), status: :created
                else
                  render_errors(@payment_session.errors)
                end
              end
            end

            # GET /api/v3/store/carts/:cart_id/payment_sessions/:id
            def show
              render json: serialize_resource(@payment_session)
            end

            # PATCH /api/v3/store/carts/:cart_id/payment_sessions/:id
            def update
              with_order_lock do
                @payment_session.reload

                @payment_session.payment_method.update_payment_session(
                  payment_session: @payment_session,
                  amount: permitted_params[:amount],
                  external_data: permitted_params[:external_data] || {}
                )

                if @payment_session.errors.empty?
                  render json: serialize_resource(@payment_session.reload)
                else
                  render_errors(@payment_session.errors)
                end
              end
            end

            # PATCH /api/v3/store/carts/:cart_id/payment_sessions/:id/complete
            #
            # Deliberately not wrapped in with_order_lock: the workflow verifies
            # the session with the gateway from an external_step, and holding a
            # row lock across that round trip is what the boundary exists to
            # prevent. Concurrency is enforced where the invariant lives —
            # PaymentSession#settle_payment! takes the owner's row lock around
            # the local settlement, so a confirm racing the webhook (or a
            # double-submitted confirm) records the capture exactly once, and a
            # replay on a completed session is an idempotent success.
            def complete
              result = Spree.payment_session_complete_workflow.call(
                payment_session: @payment_session.reload,
                params: complete_params
              )

              if result.success? && @payment_session.errors.empty?
                render json: serialize_resource(result.value)
              elsif result.success?
                render_errors(@payment_session.errors)
              else
                render_result_error(result)
              end
            end

            protected

            def serializer_class
              Spree.api.payment_session_serializer
            end

            def permitted_params
              params.permit(Spree::PermittedAttributes.payment_session_attributes)
            end

            def complete_params
              params.permit(:session_result, { external_data: {} })
            end

            private

            def set_payment_session
              @payment_session = @cart.payment_sessions.find_by_prefix_id(params[:id]) ||
                                 @cart.payment_sessions.find_by!(external_id: params[:id])
            end

            def serialize_resource(resource)
              serializer_class.new(resource, params: serializer_params).to_h
            end

            protected

            # Payment confirmation races cart completion (a webhook can finish
            # checkout before the customer returns) — only the idempotent
            # confirm replay resolves completed carts. Creating or updating a
            # session on a finished checkout stays a 404.
            def find_cart!
              super(include_completed: action_name == 'complete')
            end
          end
        end
      end
    end
  end
end