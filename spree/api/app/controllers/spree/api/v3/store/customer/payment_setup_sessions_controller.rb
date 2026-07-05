module Spree
  module Api
    module V3
      module Store
        module Customer
          class PaymentSetupSessionsController < ResourceController
            prepend_before_action :require_authentication!

            skip_before_action :set_resource
            before_action :set_payment_setup_session, only: [:show, :complete]

            # POST /api/v3/store/customer/payment_setup_sessions
            def create
              payment_method = current_store.payment_methods.find_by_prefix_id!(permitted_params[:payment_method_id])

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

            def parent_association
              :payment_setup_sessions
            end

            def model_class
              Spree::PaymentSetupSession
            end

            def serializer_class
              Spree.api.payment_setup_session_serializer
            end

            def permitted_params
              params.permit(Spree::PermittedAttributes.payment_setup_session_attributes)
            end

            def complete_params
              params.permit({ external_data: {} })
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
