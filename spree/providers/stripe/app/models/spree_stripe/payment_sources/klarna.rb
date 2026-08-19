module SpreeStripe
  module PaymentSources
    class Klarna < ::Spree::PaymentSource
      def actions
        %w[credit]
      end
    end
  end
end
