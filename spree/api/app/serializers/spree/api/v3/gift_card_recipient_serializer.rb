module Spree
  module Api
    module V3
      # Who a gift card line is for. The buyer wrote it, so it goes back to
      # them on their own cart and order.
      class GiftCardRecipientSerializer < BaseSerializer
        typelize email: :string, name: [:string, nullable: true], message: [:string, nullable: true],
                 send_at: [:string, nullable: true, comment: 'When the gift card email is sent; null sends it as soon as the order is paid.']

        attributes :email, :name, :message

        attribute :send_at do |recipient|
          recipient.send_at&.iso8601
        end
      end
    end
  end
end
