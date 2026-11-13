module GiftMessages
  # The Store API's cart update, plus the gift message. Spree's service assigns
  # the cart fields it knows by name, so a new column needs this to be saved.
  class CartUpdate < Spree::Carts::Update
    private

    def assign_cart_attributes
      super
      cart.gift_message = params[:gift_message].presence if params.key?(:gift_message)
    end
  end
end
