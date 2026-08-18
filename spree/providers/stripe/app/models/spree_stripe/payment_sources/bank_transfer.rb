module SpreeStripe
  module PaymentSources
    class BankTransfer < ::Spree::PaymentSource
      def actions
        %w[credit]
      end

      def self.display_name
        Spree.t(:bank_transfer)
      end

      def name
        Spree.t(:bank_transfer)
      end
    end
  end
end
