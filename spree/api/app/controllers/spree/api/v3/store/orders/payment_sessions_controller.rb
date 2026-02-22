module Spree
  module Api
    module V3
      module Store
        module Orders
          class PaymentSessionsController < ResourceController
            include Spree::Api::V3::OrderConcern

            skip_before_action :set_resource
            before_action :authorize_order_access!
            before_action :set_payment_session, only: [:show, :update, :complete]

            # POST /api/v3/store/orders/:order_id/payment_sessions
            def create
              payment_method = current_store.payment_methods.find_by_prefix_id!(permitted_params[:payment_method_id])

              @payment_session = payment_method.create_payment_session(
                order: @parent,
                amount: permitted_params[:amount],
                external_data: permitted_params[:external_data] || {}
              )

              if @payment_session.persisted?
                render json: serialize_resource(@payment_session), status: :created
              else
                render_errors(@payment_session.errors)
              end
            end

            # GET /api/v3/store/orders/:order_id/payment_sessions/:id
            def show
              render json: serialize_resource(@payment_session)
            end

            # PATCH /api/v3/store/orders/:order_id/payment_sessions/:id
            def update
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

            # PATCH /api/v3/store/orders/:order_id/payment_sessions/:id/complete
            def complete
              @payment_session.payment_method.complete_payment_session(
                payment_session: @payment_session,
                params: complete_params
              )

              if @payment_session.errors.empty?
                render json: serialize_resource(@payment_session.reload)
              else
                render_errors(@payment_session.errors)
              end
            end

            protected

            def parent_association
              :payment_sessions
            end

            def model_class
              Spree::PaymentSession
            end

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
              @payment_session = @parent.payment_sessions.find_by_prefix_id!(params[:id])
            end
          end
        end
      end
    end
  end
end
