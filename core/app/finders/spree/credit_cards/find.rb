module Spree
  module CreditCards
    class Find < ::Spree::BaseFinder
      def execute
        return scope.default.take if params[:id].eql?('default')
        return scope.where(payment_method_id: params[:filter]['payment_method_id']) if params[:filter].present?

        scope
      end
    end
  end
end
