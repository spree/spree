module SpreeStripe
  module PaymentSources
    class Ideal < ::Spree::PaymentSource
      store_accessor :metadata, :bank, :last4

      def actions
        %w[credit]
      end

      def self.display_name
        'iDEAL'
      end
    end
  end
end
