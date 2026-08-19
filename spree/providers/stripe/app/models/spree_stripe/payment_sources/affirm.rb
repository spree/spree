module SpreeStripe
  module PaymentSources
    class Affirm < ::Spree::PaymentSource
      def actions
        %w[credit]
      end
    end
  end
end
