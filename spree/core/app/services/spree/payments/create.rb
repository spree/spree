module Spree
  module Payments
    # @deprecated Unused since 6.0 and removed in 7.0. Nothing in Spree
    #   calls this: the storefront creates payments through the Store API
    #   controller, store credit through Spree::Checkout::AddStoreCredit,
    #   gift cards through Spree::GiftCards::Apply, and a partial capture's
    #   remainder through Spree::Payment#split_uncaptured_amount.
    #
    #   It also cannot serve those callers as written — it resolves the
    #   payment method from +params[:payment_method_id]+ against the
    #   storefront-visible list and builds a source from client attributes,
    #   while they already hold both (the gift card flow creates its payment
    #   method by type when the store has none).
    class Create
      prepend Spree::ServiceModule::Base

      def call(order:, params: {})
        ApplicationRecord.transaction do
          run :prepare_payment_attributes
          run :find_or_create_payment_source
          run :save_payment
        end
        # Gateway I/O — after the transaction, on the in-memory graph (some
        # gateways need the raw card number, which never persists).
        run :store_gateway_profile
      end

      protected

      def prepare_payment_attributes(order:, params:)
        payment_method = order.payment_methods.find { |pm| pm.id.to_s == params[:payment_method_id]&.to_s }

        payment_attributes = {
          amount: params[:amount] || order.order_total_after_store_credit,
          payment_method: payment_method
        }

        return failure(nil, :payment_method_not_found) if payment_method.blank?

        success(order: order, params: params, payment_attributes: payment_attributes)
      end

      def find_or_create_payment_source(order:, params:, payment_attributes:)
        payment_method = payment_attributes[:payment_method]

        if payment_method&.source_required?
          if order.customer.present? && params[:source_id].present?
            source = payment_method.payment_source_class.find_by(id: params[:source_id], customer: order.customer)

            return failure(nil, :source_not_found) if source.nil?
          else
            result = Wallet::CreatePaymentSource.call(
              payment_method: payment_method,
              params: params.delete(:source_attributes),
              user: order.customer
            )

            return failure(nil, result.error.value) if result.failure?

            source = result.value
          end

          payment_attributes[:source] = source
        end

        success(order: order, payment_attributes: payment_attributes)
      end

      def save_payment(order:, payment_attributes:)
        payment = order.payments.new(payment_attributes)

        if payment.save
          success(payment: payment)
        else
          failure(payment)
        end
      end

      # A payment that cannot be profiled must not linger half-created — the
      # old after_save callback rolled the whole save back on gateway failure.
      def store_gateway_profile(payment:)
        return success(payment) unless payment.profiles_supported?

        payment.create_payment_profile
        success(payment)
      rescue Spree::Core::GatewayError => e
        payment.destroy
        failure(payment, e.message)
      end
    end
  end
end
