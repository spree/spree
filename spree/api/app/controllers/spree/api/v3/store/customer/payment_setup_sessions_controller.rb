module Spree
  module Api
    module V3
      module Store
        module Customer
          class PaymentSetupSessionsController < ResourceController
            prepend_before_action :require_authentication!

            skip_before_action :set_resource
            before_action :set_payment_setup_session, only: [:show, :complete]

            request_params 'CreatePaymentSetupSessionParams', action: :create do
              id :payment_method_id, required: true, example: 'pm_abc123'
              object :external_data, description: 'Provider-specific data passed to the gateway.'
            end

            request_params 'CompletePaymentSetupSessionParams', action: :complete do
              object :external_data, description: 'Provider-specific completion data.'
            end

            # POST /api/v3/store/customer/payment_setup_sessions
            def create
              payment_method = current_store.payment_methods.find_by_prefix_id!(params[:payment_method_id])

              @payment_setup_session = payment_method.create_payment_setup_session(
                customer: current_user,
                external_data: permitted_params[:external_data] || {}
              )

              if @payment_setup_session.persisted?
                render json: serialize_resource(@payment_setup_session), status: :created
              else
                render_errors(@payment_setup_session.errors)
              end
            end

            # GET /api/v3/store/customer/payment_setup_sessions/:id
            def show
              render json: serialize_resource(@payment_setup_session)
            end

            # PATCH /api/v3/store/customer/payment_setup_sessions/:id/complete
            def complete
              @payment_setup_session.payment_method.complete_payment_setup_session(
                setup_session: @payment_setup_session,
                params: complete_params
              )

              if @payment_setup_session.errors.empty?
                render json: serialize_resource(@payment_setup_session.reload)
              else
                render_errors(@payment_setup_session.errors)
              end
            end

            protected

            def set_parent
              @parent = current_user
            end

            def model_class
              Spree::PaymentSetupSession
            end

            def serializer_class
              Spree.api.payment_setup_session_serializer
            end

            def complete_params
              params.permit(*declared_permitted_attributes)
            end

            private

            def set_payment_setup_session
              @payment_setup_session = current_user.payment_setup_sessions.find_by_prefix_id!(params[:id])
            end
          end
        end
      end
    end
  end
end
