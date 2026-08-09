module SpreeStripe
  module PaymentSources
    class Alipay < ::Spree::PaymentSource
      def actions
        %w[credit]
      end
    end
  end
end
