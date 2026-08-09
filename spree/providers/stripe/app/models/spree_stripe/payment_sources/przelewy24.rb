module SpreeStripe
  module PaymentSources
    class Przelewy24 < ::Spree::PaymentSource
      store_accessor :metadata, :bank

      def actions
        %w[credit]
      end
    end
  end
end
