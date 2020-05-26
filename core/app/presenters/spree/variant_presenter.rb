module Spree
  class VariantPresenter
    include Rails.application.routes.url_helpers
    include Spree::BaseHelper

    attr_reader :current_currency, :current_price_options

    def initialize(opts = {})
      @variants = opts[:variants]
      @is_product_available_in_currency = opts[:is_product_available_in_currency]
      @current_currency = opts[:current_currency]
      @current_price_options = opts[:current_price_options]
    end

    def call
      @variants.map do |variant|
        {
          display_price: display_price(variant),
          price: variant.price_in(current_currency),
          display_compare_at_price: display_compare_at_price(variant),
          should_display_compare_at_price: should_display_compare_at_price(variant),
          is_product_available_in_currency: @is_product_available_in_currency,
          backorderable: backorderable?(variant),
          in_stock: in_stock?(variant),
          images: images(variant),
          option_values: option_values(variant),
        }.merge(
          variant_attributes(variant)
        )
      end
    end

    def images(variant)
      variant.images.map do |image|
        {
          alt: image.alt,
          url_product: rails_representation_url(image.url(:product), only_path: true)
        }
      end
    end

    def option_values(variant)
      variant.option_values.map do |option_value|
        {
          id: option_value.id,
          name: option_value.name,
          presentation: option_value.presentation,
        }
      end
    end

    private

    def backorderable?(variant)
      backorderable_variant_ids.include?(variant.id)
    end

    def backorderable_variant_ids
      @backorderable_variant_ids ||= Spree::Variant.where(id: @variants.map(&:id)).backorderable.ids
    end

    def in_stock?(variant)
      in_stock_variant_ids.include?(variant.id)
    end

    def in_stock_variant_ids
      @in_stock_variant_ids ||= Spree::Variant.where(id: @variants.map(&:id)).in_stock.ids
    end

    def variant_attributes(variant)
      {
        id: variant.id,
        sku: variant.sku,
        purchasable: variant.purchasable?
      }
    end

    def should_display_compare_at_price(variant)
      variant.compare_at_price.present? && variant.compare_at_price > variant.price
    end
  end
end
