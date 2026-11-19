module Spree
  module Emails
    # What an email shows for a purchased line besides its Store API fields: a
    # link to the product on the storefront and a thumbnail. Shared by the line
    # item and parcel item serializers.
    module PurchasedItemAttributes
      extend ActiveSupport::Concern
      include Spree::ImagesHelper

      included do
        attribute :url do |item|
          product = purchased_variant(item).product
          "#{params[:storefront_url]}/products/#{product.slug}" if product
        end

        attribute :image_url do |item|
          spree_image_url(purchased_variant(item).thumbnail, variant: :small)
        end
      end

      private

      # A parcel item's own variant, which differs from its line item's for an
      # exchange replacement.
      def purchased_variant(item)
        item.variant || item.line_item.variant
      end
    end
  end
end
