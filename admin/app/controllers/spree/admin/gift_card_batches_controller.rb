module Spree
  module Admin
    class GiftCardBatchesController < ResourceController
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
