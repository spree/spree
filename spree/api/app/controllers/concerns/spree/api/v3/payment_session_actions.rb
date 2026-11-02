module Spree
  module Api
    module V3
      # Payment session actions shared by everything a storefront buyer pays
      # for: a cart at checkout, and a draft order the merchant raised for
      # them. The including controller resolves and authorizes the owner in a
      # before_action and answers it from +payment_session_owner+.
      module PaymentSessionActions
        extend ActiveSupport::Concern

        include Spree::Api::V3::OrderLock

        included do
          before_action :set_payment_session, only: [:show, :update, :complete]

          request_params 'CreatePaymentSessionParams', action: :create do |body|
            body.attribute :payment_method_id, :id, required: true, example: 'pm_abc123'
            body.attribute :amount, :decimal,
              example: '99.99',
              description: 'Defaults to the order total minus store credits.'
            body.attribute :external_data, :hash, description: 'Provider-specific data passed to the gateway.'
          end

          request_params 'UpdatePaymentSessionParams', action: :update do |body|
            body.attribute :amount, :decimal, example: '50.00'
            body.attribute :external_data, :hash, description: 'Provider-specific data to update.'
          end

          request_params 'CompletePaymentSessionParams', action: :complete do |body|
            body.attribute :session_result, :string, description: 'Provider-specific session result token.'
            body.attribute :external_data, :hash, description: 'Provider-specific completion data.'
          end
        end

        def create
          with_order_lock do
            payment_method = current_store.payment_methods.active.storefront_visible.
                             find_by_prefix_id!(permitted_params[:payment_method_id])

            unless payment_method.available_for_order?(payment_session_owner)
              return render_error(
                code: 'payment_method_unavailable',
                message: I18n.t('spree.api.v3.payments.method_unavailable'),
                status: :unprocessable_content
              )
            end

            @payment_session = payment_method.create_payment_session(
              order: payment_session_owner,
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

        def show
          render json: serialize_resource(@payment_session)
        end

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

        # @return [Spree::Cart, Spree::Order] what the sessions pay for
        def payment_session_owner
          raise NotImplementedError, "#{self.class.name} must define payment_session_owner"
        end

        def serializer_class
          Spree.api.payment_session_serializer
        end

        def permitted_params
          params.permit(*declared_permitted_attributes, *Spree::PaymentSession.additional_permitted_attributes)
        end

        def complete_params
          params.permit(*declared_permitted_attributes)
        end

        private

        def set_payment_session
          @payment_session = payment_session_owner.payment_sessions.find_by_prefix_id(params[:id]) ||
                             payment_session_owner.payment_sessions.find_by!(external_id: params[:id])
        end

        def serialize_resource(resource)
          serializer_class.new(resource, params: serializer_params).to_h
        end
      end
    end
  end
end
