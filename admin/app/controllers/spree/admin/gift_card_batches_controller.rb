module Spree
  module Admin
    class GiftCardBatchesController < ResourceController
      add_breadcrumb_icon 'discount'
      add_breadcrumb Spree.t(:promotions), :admin_promotions_path
      add_breadcrumb Spree.t(:gift_cards), :admin_gift_cards_path

      private

      def location_after_save
        spree.admin_gift_cards_path(q: { batch_prefix_eq: @object.prefix })
      end

      def collection_url
        spree.admin_gift_cards_path
      end

      def permitted_resource_params
        params.require(:gift_card_batch).permit(permitted_gift_card_batch_attributes)
      end
    end
  end
end
