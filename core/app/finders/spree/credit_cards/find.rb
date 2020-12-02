module Spree
  module CreditCards
    class Find
      def initialize(scope:, params:)
        @scope = scope
        @payment_method_id = params.dig(:filter, :payment_method_id)
      end

      def execute
        credit_cards = by_payment_method_id(scope)

        credit_cards
      end

      private

      attr_reader :payment_method_id, :scope

      def payment_method_id?
        payment_method_id.present?
      end

      def by_payment_method_id(scope)
        return scope unless payment_method_id?

        scope.where(payment_method_id: payment_method_id)
      end
    end
  end
end
