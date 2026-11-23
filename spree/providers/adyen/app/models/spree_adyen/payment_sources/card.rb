module SpreeAdyen
  module PaymentSources
    # A card paid with but not saved: a guest's, or one the buyer did not ask
    # to keep. Adyen gives no number, name or expiry a Spree::CreditCard needs,
    # and it could never be charged again, so it must not show among saved cards.
    class Card < Base
      store_accessor :metadata, :brand, :last_digits, :wallet

      def self.display_name
        'Card'
      end
    end
  end
end
