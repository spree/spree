module Spree
  module Imports
    module RowProcessors
      class ProductVariant < Base
        OPTION_TYPES_COUNT = 3

        def initialize(row)
          super
          @store = Spree::Store.current || Spree::Store.default
          @product = ensure_product_exists
        end

        attr_reader :product, :store

        def process!
          variant_scope = options.empty? ? product.variants_including_master : product.variants

          variant = if attributes['sku'].present?
                      variant_scope.where(
                        Spree::Variant.arel_table[:sku].lower.eq(attributes['sku'].strip.downcase)
                      ).first || product.variants.new
                    elsif options.empty?
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
          variant.option_value_variants = prepare_option_value_variants
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
            existing_product = Spree::Product.find_by(slug: attributes['slug'].strip.downcase)
            product = existing_product if existing_product.present?
          end

          # setting SKU for master variant so it will be picked up in process! and won't try to create a non-master variant
          if product.new_record?
            product.slug = attributes['slug']
            product.sku = attributes['sku'] if attributes['sku'].present? && options.empty?
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

        def prepare_option_value_variants
          return [] if options.empty?

          options.map do |option|
            option_type = Spree::OptionType.search_by_name(option[:option_name]).first || Spree::OptionType.create!(presentation: option[:option_name])
            option_value = option_type.option_values.search_by_name(option[:option_value]).first || option_type.option_values.create!(presentation: option[:option_value])

            # ensure product option types include new option type
            Spree::ProductOptionType.find_or_create_by!(product: product, option_type: option_type)

            Spree::OptionValueVariant.new(option_value: option_value)
          end
        end

        def options
          @options ||= begin
            options = []

            OPTION_TYPES_COUNT.times.map do |index|
              next if attributes["option#{index + 1}_name"].blank?
              next if attributes["option#{index + 1}_value"].blank?

              options << {
                index: index + 1,
                option_name: attributes["option#{index + 1}_name"],
                option_value: attributes["option#{index + 1}_value"]
              }
            end

            options
          end
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
