module Spree
  module Api
    module V3
      module Store
        # Who a gift card line is for, as a shopper writes it when adding a
        # denomination to the cart or changing the line later.
        class GiftCardRecipientRequestSchema < Spree::Api::V3::RequestSchema
          publishes 'GiftCardRecipientParams'

          attribute :email, :string, format: :email, required: true, example: 'friend@example.com'
          attribute :name, :string, example: 'Alex'
          attribute :message, :string, example: 'Happy birthday!', description: 'At most 500 characters.'
          attribute :send_at, :datetime,
                    description: 'When to email the gift card, at most 90 days ahead. Omit to send it as soon as the order is paid.'
        end
      end
    end
  end
end
