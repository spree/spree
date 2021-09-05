module Spree
  class WishlistsController < Spree::StoreController
    include Spree::FrontendHelper
    include Spree::CacheHelper

    include Spree::Core::ControllerHelpers::Order

    helper 'spree/products'

    before_action :load_wishlist, only: [:destroy, :show, :update, :edit]

    respond_to :html

    def new
      @wishlist = Spree::Wishlist.new

      ensure_current_store(@wishlist)
      respond_with(@wishlist)
    end

    def index
      @wishlists = spree_current_user.wishlists
      respond_with(@wishlist)
    end

    def edit
      respond_with(@wishlist)
    end

    def update
      @wishlist.update wishlist_attributes
      respond_with(@wishlist)
    end

    def show
      respond_with(@wishlist)
    end

    def default
      @wishlist = spree_current_user.wishlist
      respond_with(@wishlist) do |format|
        format.html { render :show }
      end
    end

    def create
      @wishlist = Spree::Wishlist.new wishlist_attributes
      @wishlist.user = spree_current_user

      ensure_current_store(@wishlist)

      @wishlist.save

      respond_with(@wishlist)
    end

    def destroy
      @wishlist.destroy
      respond_with(@wishlist) do |format|
        format.html { redirect_to account_path }
      end
    end

    private

    def wishlist_attributes
      params.require(:wishlist).permit(:name, :is_default, :is_private, :store_id, :store)
    end

    def load_wishlist
      @wishlist = current_store.wishlists.find_by(token: params[:id])
    end
  end
end
