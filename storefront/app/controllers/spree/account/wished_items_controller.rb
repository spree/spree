module Spree
  module Account
    class WishedItemsController < BaseController
      # POST /account/wished_items
      def create
        variant = current_store.variants.find(wished_item_params[:variant_id])
        @wished_item = current_wishlist.wished_items.build(variant: variant)

        if @wished_item.save
          track_event('product_added_to_wishlist', variant: variant)
        else
          flash.now[:error] = @wished_item.errors.full_messages.to_sentence.strip
        end

        respond_to do |format|
          format.html { redirect_to spree.account_wishlist_path }
          format.turbo_stream
        end
      end

      def destroy
        @wished_item = current_wishlist.wished_items.find_by!(variant_id: params[:id])

        if @wished_item.destroy
          track_event('product_removed_from_wishlist', variant: @wished_item.variant)
        else
          flash.now[:error] = Spree.t('storefront.wished_items.remove_error')
        end

        respond_to do |format|
          format.html { redirect_to spree.account_wishlist_path }
          format.turbo_stream
        end
      end

      private

      def wished_item_params
        params.require(:wished_item).permit(:variant_id)
      end
    end
  end
end
