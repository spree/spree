module GiftMessages
  # Carries the gift message from the cart onto the order it becomes.
  class CopyToOrder
    def self.call(cart:, order:, line_item_map:) # rubocop:disable Lint/UnusedMethodArgument
      return if cart.gift_message.blank?

      order.update!(gift_message: cart.gift_message)
    end
  end
end
