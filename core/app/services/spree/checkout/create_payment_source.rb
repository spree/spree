module Spree
  module Checkout
    class CreatePaymentSource
      prepend Spree::ServiceModule::Base

      def call(order:, user:, source_attributes:)
        run :find_payment_method
        run :create_source
      end

      protected

      def find_payment_method(order:, user:, source_attributes:)
        payment_method = order.available_payment_methods.find { |pm| pm.id.to_s == source_attributes[:payment_method_id].to_s }

        return failure(:payment_method_not_found) unless payment_method.present?

        success(user: user, source_attributes: source_attributes, payment_method: payment_method)
      end

      def create_source(user:, source_attributes:, payment_method:)
        return failure(:payment_method_does_not_support_sources) if payment_method.try(:payment_source_class).nil?

        source = payment_method.payment_source_class.new(source_attributes.merge(user_id: user&.id))

        if source.save
          success(source: source)
        else
          failure(:source_could_not_be_saved, errors: source.errors.full_messages)
        end
      end
    end
  end
end