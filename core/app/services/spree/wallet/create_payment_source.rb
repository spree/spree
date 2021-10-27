module Spree
  module Wallet
    class CreatePaymentSource
      prepend Spree::ServiceModule::Base

      def call(payment_method:, source_attributes:, user: nil)
        return failure(nil, :payment_method_not_found) unless payment_method
        return failure(nil, :payment_method_does_not_support_sources) if payment_method.try(:payment_source_class).nil?

        source = payment_method.payment_source_class.new(source_attributes.merge(user_id: user&.id))

        if source.save
          success(source)
        else
          failure(source)
        end
      end
    end
  end
end
