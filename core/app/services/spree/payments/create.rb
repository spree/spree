module Spree
  module Payments
    class Create
      prepend Spree::ServiceModule::Base

      def call(order:, params: {}, user: nil)
        payment_method = order.available_payment_methods.find { |pm| pm.id.to_s == params[:payment_method_id]&.to_s }

        payment_attributes = {
          amount: params[:amount] || order.total - order.payment_total,
          payment_method: payment_method
        }

        if payment_method.source_required?
          if user.present? && params[:source_id].present?
            payment_attributes[:source] = payment_method.payment_source_class.find_by(id: params[:source_id])
          else
            payment_attributes[:source_attributes] = params.permit(
              :payment_method_id,
              :gateway_payment_profile_id,
              :gateway_customer_profile_id,
              :last_digits,
              :month,
              :year,
              :name
            ).merge(user_id: user&.id)
          end
        end

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
