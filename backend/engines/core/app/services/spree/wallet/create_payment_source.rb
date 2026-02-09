module Spree
  module Wallet
    class CreatePaymentSource
      prepend Spree::ServiceModule::Base

      def call(payment_method:, params: {}, user: nil)
        return failure(nil, :missing_attributes) if params.nil?

        source_attributes = {
          payment_method_id: payment_method.id,
          user_id: user&.id,
          gateway_payment_profile_id: params[:gateway_payment_profile_id],
          gateway_customer_profile_id: params[:gateway_customer_profile_id],
          last_digits: params[:last_digits],
          month: params[:month],
          year: params[:year],
          name: params[:name]
        }

        source = payment_method.payment_source_class.new(source_attributes)

        source.save ? success(source) : failure(source)
      end
    end
  end
end
