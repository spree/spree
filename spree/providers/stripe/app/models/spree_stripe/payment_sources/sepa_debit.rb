module SpreeStripe
  module PaymentSources
    class SepaDebit < ::Spree::PaymentSource
      def actions
        %w[credit]
      end

      def self.display_name
        'SEPA Debit'
      end

      def name
        'SEPA Debit'
      end
    end
  end
end
