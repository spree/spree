module Spree
  module WishlistHelper
    # Returns the current wishlist for the current user.
    #
    # @return [Spree::Wishlist] The current wishlist
    def current_wishlist
      @current_wishlist ||= try_spree_current_user&.default_wishlist_for_store(current_store)
    end
  end
end
