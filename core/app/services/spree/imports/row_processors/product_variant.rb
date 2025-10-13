module Spree
  module Imports
    module RowProcessors
      class ProductVariant < Base
        def initialize(row)
          super
          @store = Spree::Store.current || Spree::Store.default
          @product = ensure_product_exists
        end

        attr_reader :product, :store

        def process!
          variant = if attributes['sku'].present?
                      product.variants.where(
                        Spree::Variant.arel_table[:sku].lower.eq(attributes['sku'].strip.downcase)
                      ).first || product.variants.new
                    elsif attributes['option1_name'].blank?
                      product.master
                    else
                      product.variants.new
                    end

          variant.sku = attributes['sku'] if attributes['sku'].present?
          variant.cost_price = attributes['cost_price'] if attributes['cost_price'].present?
          variant.weight = attributes['weight'] if attributes['weight'].present?
          variant.height = attributes['height'] if attributes['height'].present?
          variant.width = attributes['width'] if attributes['width'].present?
          variant.depth = attributes['depth'] if attributes['depth'].present?
          variant.track_inventory = attributes['track_inventory'] if attributes['track_inventory'].present?
          variant.save!

          if attributes['currency'].present? && attributes['price'].present?
            currency = attributes['currency'].strip.upcase || store.default_currency
            variant.set_price(currency, attributes['price'], attributes['compare_at_price'])
          end

          if attributes['inventory_count'].present?
            variant.set_stock(attributes['inventory_count'].to_i, attributes['inventory_backorderable']&.to_b, store.default_stock_location)
          end

          variant
        end

        private

        def ensure_product_exists
          product = Spree::Product.new
          if attributes['slug'].present?
            product = Spree::Product.find_by(slug: attributes['slug'].strip.downcase)
          end

          product.stores << store if product.new_record? && product.stores.exclude?(store)
          product.name = attributes['name'] if attributes['name'].present?
          product.description = attributes['description'] if attributes['description'].present?
          product.meta_title = attributes['meta_title'] if attributes['meta_title'].present?
          product.meta_description = attributes['meta_description'] if attributes['meta_description'].present?
          product.meta_keywords = attributes['meta_keywords'] if attributes['meta_keywords'].present?
          product.status = to_spree_status(attributes['status']) if attributes['status'].present?
          product.save!
          product
        end

        def to_spree_status(status)
          case status.strip.downcase
          when 'active'
            'active'
          when 'draft'
            'draft'
          when 'archived'
            'archived'
          else
            'draft'
          end
        end
      end
    end
  end
end
