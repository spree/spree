module Spree
  class WishedProductsController < Spree::StoreController
    include Spree::Core::ControllerHelpers::Order

    before_action :load_default_wishlist, only: [:create]

    respond_to :html

    def create
      @wished_product = Spree::WishedProduct.new(wished_product_attributes)

      if @default_wishlist.include? params[:wished_product][:variant_id]
        @wished_product = @default_wishlist.wished_products.detect { |wp| wp.variant_id == params[:wished_product][:variant_id].to_i }
      else
        @wished_product.wishlist = spree_current_user.wishlist(current_store.id)
        @wished_product.save
      end

      respond_with(@wished_product) do |format|
        format.html { redirect_to wishlist_url(@default_wishlist) }
      end
    end

    def update
      @wished_product = Spree::WishedProduct.find(params[:id])
      @wished_product.update(wished_product_attributes)

      respond_with(@wished_product) do |format|
        format.html { redirect_to wishlist_url(@wished_product.wishlist) }
      end
    end

    def destroy
      @wished_product = Spree::WishedProduct.find(params[:id])
      @wished_product.destroy

      respond_with(@wished_product) do |format|
        format.html { redirect_to wishlist_url(@wished_product.wishlist), status: :see_other }
      end
    end

    private

    def load_default_wishlist
      @default_wishlist = spree_current_user.wishlists.find_by(store_id: current_store.id, is_default: true)

      if @default_wishlist.nil?
        @default_wishlist = spree_current_user.wishlist(current_store.id)

        @default_wishlist
      end
    end

    def wished_product_attributes
      params.require(:wished_product).permit(:variant_id, :remark, :quantity)
    end
  end
end
