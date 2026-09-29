module Spree
  module Emails
    # What an email shows for a purchased line: its SKU, a link to the
    # product on the storefront and a thumbnail. Shared by the line item and
    # parcel item serializers.
    module PurchasedItemAttributes
      extend ActiveSupport::Concern
      include Spree::ImagesHelper

      included do
        attribute :sku do |item|
          purchased_line_item(item).variant&.sku
        end

        attribute :options_text do |item|
          purchased_line_item(item).variant&.options_text
        end

        attribute :url do |item|
          product = purchased_line_item(item).product
          "#{params[:store].storefront_url.to_s.chomp('/')}/products/#{product.slug}" if product
        end

        attribute :image_url do |item|
          spree_image_url(purchased_line_item(item).variant&.thumbnail, variant: :small)
        end
      end

      private

      def purchased_line_item(item)
        item.is_a?(Spree::LineItem) ? item : item.line_item
      end
    end
  end
end
