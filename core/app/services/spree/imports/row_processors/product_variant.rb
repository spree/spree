module Spree
  module Imports
    module RowProcessors
      class ProductVariant < Base
        OPTION_TYPES_COUNT = 3

        def initialize(row)
          super
          @store = row.store
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

          if attributes['price'].present?
            currency = (attributes['currency'].presence || store.default_currency).to_s.strip.upcase
            variant.set_price(currency, attributes['price'], attributes['compare_at_price'])
          end

          if attributes['inventory_count'].present?
            variant.set_stock(attributes['inventory_count'].to_i, attributes['inventory_backorderable']&.to_b, store.default_stock_location)
          end

          handle_images(variant)

          variant
        end

        private

        def ensure_product_exists
          product = Spree::Product.new
          if attributes['slug'].present?
            existing_product = product_scope.find_by(slug: attributes['slug'].strip.downcase)
            product = existing_product if existing_product.present?
          end

          product = assign_attributes_to_product(product)
          product.save!
          handle_metafields(product)
          product
        end

        def product_scope
          Spree::Product.accessible_by(import.current_ability, :manage)
        end

        def assign_attributes_to_product(product)
          # setting SKU for master variant so it will be picked up in process! and won't try to create a non-master variant
          if product.new_record?
            product.slug = attributes['slug']
            product.sku = attributes['sku'] if attributes['sku'].present? && options.empty?
          end

          product.stores << store if product.stores.exclude?(store)
          product.name = attributes['name'] if attributes['name'].present?
          product.description = attributes['description'] if attributes['description'].present?
          product.meta_title = attributes['meta_title'] if attributes['meta_title'].present?
          product.meta_description = attributes['meta_description'] if attributes['meta_description'].present?
          product.meta_keywords = attributes['meta_keywords'] if attributes['meta_keywords'].present?
          product.status = to_spree_status(attributes['status']) if attributes['status'].present?
          product.tag_list = attributes['tags'] if attributes['tags'].present?

          product.taxons = prepare_taxons if options.empty?
          product
        end

        def prepare_taxons
          taxon_pretty_names = [
            attributes['category1'],
            attributes['category2'],
            attributes['category3']
          ].compact_blank.map(&:strip).uniq

          return [] if taxon_pretty_names.empty?

          taxons = taxon_pretty_names.map { |taxon_pretty_name| handle_taxon_line(taxon_pretty_name) }
          taxons.compact
        end

        def handle_taxon_line(taxon_pretty_name)
          taxon_names = taxon_pretty_name.strip.split('->').map(&:strip).map(&:presence).compact
          return if taxon_names.empty?

          taxonomy_name = taxon_names.shift
          taxonomy = store.taxonomies.with_matching_name(taxonomy_name).first || store.taxonomies.create!(name: taxonomy_name)

          last_taxon = taxonomy.root

          taxon_names.each do |taxon_name|
            last_taxon = taxonomy.taxons.with_matching_name(taxon_name).where(parent: last_taxon).first || taxonomy.taxons.create!(name: taxon_name, parent: last_taxon)
          end

          last_taxon
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

        def handle_images(variant)
          image_urls = [
            attributes['image1_src'],
            attributes['image2_src'],
            attributes['image3_src'],
          ].compact.map(&:strip).compact_blank.uniq

          return if image_urls.empty?

          image_urls.each do |image_url|
            Spree::Images::SaveFromUrlJob.perform_later(variant.id, 'Spree::Variant', image_url)
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

        def handle_metafields(product)
          return unless product.class.included_modules.include?(Spree::Metafields)

          metafield_attributes = attributes.select { |key, _value| key.to_s.start_with?('metafield.') }
          
          metafield_attributes.each do |attribute_key, value|
            next if value.blank?
            
            # Extract namespace.key from "metafield.namespace.key"
            full_key = attribute_key.to_s.sub(/^metafield\./, '')
            product.set_metafield(full_key, value.to_s.strip)
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
