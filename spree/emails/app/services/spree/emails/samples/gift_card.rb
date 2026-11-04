module Spree
  module Emails
    module Samples
      # The gift card email. Always a made-up card: a real one would show a
      # spendable code to whoever previews the template.
      class GiftCard < Base
        def variables
          {
            gift_card: data(sample_gift_card, Spree::Emails::GiftCardSerializer),
            recipient_name: 'Alex',
            message: 'Happy birthday! Treat yourself.',
            sender_name: 'Sam Taylor'
          }
        end

        private

        def sample_gift_card
          Spree::GiftCard.new(store: store, code: 'giftsample1234', amount: 50, currency: currency, expires_at: 1.year.from_now.to_date)
        end
      end
    end
  end
end
