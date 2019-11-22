module Spree
  class VariantPresenter
    include Rails.application.routes.url_helpers
    include Spree::BaseHelper

    def initialize(variants)
      @variants = variants
    end

    def call
      @variants.map do |variant|
        is_product_available_in_currency = variant.product.price_in(variant.cost_currency) && !variant.product.price.nil?
        {
          display_price: variant.display_price.to_s,
          is_product_available_in_currency: is_product_available_in_currency,
          backorderable: backorderable?(variant),
          images: images(variant),
          option_values: option_values(variant),
          category: variant.product.category&.name,
          brand: variant.product.brand&.name,
        }.merge(
          variant_attributes(variant)
        )
      end
    end

    def images(variant)
      variant.images.map do |image|
        {
          viewable_type: image.viewable_type,
          viewable_id: image.viewable_id,
          attachment_width: image.attachment_width,
          attachment_height: image.attachment_height,
          attachment_file_size: image.attachment_file_size,
          position: image.position,
          attachment_content_type: image.attachment_content_type,
          attachment_file_name: image.attachment_file_name,
          type: image.type,
          alt: image.alt,
          url_mini: url_for(image.url(:mini)),
          url_product: url_for(image.url(:product))
        }
      end
    end

    def option_values(variant)
      variant.option_values.map do |option_value|
        {
          id: option_value.id,
          position: option_value.position,
          name: option_value.name,
          presentation: option_value.presentation,
          option_type: {
            id: option_value.option_type.id,
            position: option_value.option_type.position,
            name: option_value.option_type.name,
            presentation: option_value.option_type.presentation
          }
        }
      end
    end

    private

    def backorderable?(variant)
      backorderable_variant_ids.include?(variant.id)
    end

    def backorderable_variant_ids
      @backorderable_variant_ids ||= Spree::Variant.joins(:stock_items).where(id: @variants.map(&:id)).
        where(spree_stock_items: { backorderable: true }).merge(Spree::StockItem.with_active_stock_location).distinct.ids
    end

    def variant_attributes(variant)
      {
        id: variant.id,
        sku: variant.sku,
        weight: variant.weight,
        height: variant.height,
        width: variant.width,
        depth: variant.depth,
        is_master: variant.is_master,
        product_id: variant.product_id,
        price: variant.price,
        in_stock: variant.in_stock?,
        purchasable: variant.purchasable?,
        position: variant.position,
        cost_currency: variant.cost_currency,
        track_inventory: variant.track_inventory,
        tax_category_id: variant.tax_category_id,
        options_text: variant.options_text,
        name: variant.name
      }
    end
  end
end
