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
    end
  end
end
