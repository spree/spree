module Spree
  module Payments
    class Create
      prepend Spree::ServiceModule::Base

      def call(order:, params: {}, user: nil)
        ApplicationRecord.transaction do
          run :prepare_payment_attributes
          run :prepare_source_attributes
          run :save_payment
        end
      end

      protected

      def prepare_payment_attributes(order:, params:, user: nil)
        payment_attributes = {
          amount: params[:amount] || order.total - order.payment_total,
          payment_method: order.available_payment_methods.find { |pm| pm.id.to_s == params[:payment_method_id]&.to_s }
        }

        success(order: order, params: params, user: user, payment_attributes: payment_attributes)
      end

      def prepare_source_attributes(order:, params:, payment_attributes:, user: nil)
        payment_method = payment_attributes[:payment_method]

        if payment_method&.source_required?
          if user.present? && params[:source_id].present?
            payment_attributes[:source] = payment_method.payment_source_class.find_by(id: params[:source_id])
          else
            payment_attributes[:source_attributes] = params.permit(permitted_source_attributes).merge(user_id: user&.id)
          end
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

      def permitted_source_attributes
        %i[
          payment_method_id
          gateway_payment_profile_id
          gateway_customer_profile_id
          last_digits
          month
          year
          name
        ]
      end
    end
  end
end
