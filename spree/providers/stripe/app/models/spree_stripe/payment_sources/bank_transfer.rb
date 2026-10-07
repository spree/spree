module SpreeStripe
  module PaymentSources
    class BankTransfer < ::Spree::PaymentSource
      def actions
        %w[credit]
      end

      def self.display_name
        I18n.t('spree.bank_transfer')
      end

      def name
        I18n.t('spree.bank_transfer')
      end
    end
  end
end
