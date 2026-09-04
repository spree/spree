module Spree
  module Api
    module V3
      module Seller
        # The seller's view of a label on one of their parcels — the same
        # facts the operator sees, downloaded through the seller branch.
        class ShippingLabelSerializer < Admin::ShippingLabelSerializer
          attribute :download_url do |shipping_label|
            next nil unless shipping_label.file.attached? || shipping_label.file_pending?

            next nil if shipping_label.owner.order.nil?

            Spree::Core::Engine.routes.url_helpers.download_api_v3_seller_order_fulfillment_label_path(
              order_id: shipping_label.owner.order.prefixed_id,
              fulfillment_id: shipping_label.owner.prefixed_id,
              id: shipping_label.prefixed_id
            )
          end
        end
      end
    end
  end
end
