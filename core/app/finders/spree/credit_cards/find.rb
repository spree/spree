module Spree
  module CreditCards
    class Find
      def execute(scope:, params:)
        return scope.credit_cards.default if params[:id].eql?('default')
        return scope.credit_cards.where(payment_method_id: params[:filter]['payment_method_id']) if params[:filter].present?

        scope.credit_cards
      end
    end
  end
end
