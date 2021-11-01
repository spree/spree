module Spree
  module Payments
    class Create
      prepend Spree::ServiceModule::Base

      def call(order:, params: {})
        ApplicationRecord.transaction do
          run :prepare_payment_attributes
          run :find_or_create_payment_source
          run :save_payment
        end
      end

      protected

      def prepare_payment_attributes(order:, params:)
        payment_method = order.available_payment_methods.find { |pm| pm.id.to_s == params[:payment_method_id]&.to_s }

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
          if order.user.present? && params[:source_id].present?
            source = payment_method.payment_source_class.find_by(id: params[:source_id], user: order.user)

            return failure(nil, :source_not_found) if source.nil?
          else
            result = Wallet::CreatePaymentSource.call(
              payment_method: payment_method,
              params: params.delete(:source_attributes),
              user: order.user
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
          success(payment)
        else
          failure(payment)
        end
      end
    end
  end
end
