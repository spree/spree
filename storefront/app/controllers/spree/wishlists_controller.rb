module Spree
  class WishlistsController < StoreController
    def show
      if params[:id].present? && params[:token].present?
        @wishlist = current_store.wishlists.find_by!(id: params[:id], token: params[:token])
      elsif try_spree_current_user
        # https://github.com/spree/spree/blob/9475c6633b762669ee0c8f1f8a4d73e1c221a94e/core/app/models/concerns/spree/user_methods.rb#L71
        @wishlist = try_spree_current_user.default_wishlist_for_store(current_store)
      else
        return require_user
      end

      @wished_items = @wishlist.wished_items.includes(
        product: [:prices_including_master, :variants, :master, :taggings],
        variant: [:images, :product, { option_values: :option_type }]
      )
    end
  end
end
