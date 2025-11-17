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

          if attributes['tax_category'].present?
            tax_category = prepare_tax_category
            variant.tax_category = tax_category if tax_category.present?
          end

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
          if options.empty?
            # For master variants, create or update the product
            product = Spree::Product.new
            if attributes['slug'].present?
              existing_product = product_scope.find_by(slug: attributes['slug'].strip.downcase)
              product = existing_product if existing_product.present?
            end

            product = assign_attributes_to_product(product)
            product.save!
            handle_metafields(product)
            product
          else
            # For non-master variants, only look up the product
            if attributes['slug'].present?
              product_scope.find_by!(slug: attributes['slug'].strip.downcase)
            else
              raise ActiveRecord::RecordNotFound, 'Product slug is required for variant rows'
            end
          end
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

          if options.empty?
            if attributes['shipping_category'].present?
              shipping_category = prepare_shipping_category
              product.shipping_category = shipping_category if shipping_category.present?
            end
            product.taxons = prepare_taxons
          end

          product
        end

        def prepare_shipping_category
          shipping_category_name = attributes['shipping_category'].strip
          Spree::ShippingCategory.find_by(name: shipping_category_name)
        end

        def prepare_tax_category
          tax_category_name = attributes['tax_category'].strip
          Spree::TaxCategory.find_by(name: tax_category_name)
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
          return if metafield_attributes.empty?

          # Build nested attributes for metafields
          nested_attrs = []

          metafield_attributes.each do |attribute_key, value|
            # Extract namespace.key from "metafield.namespace.key"
            full_key = attribute_key.to_s.sub(/^metafield\./, '')
            namespace, key = product.extract_namespace_and_key(full_key)

            # Find or initialize metafield definition
            metafield_definition = Spree::MetafieldDefinition.find_by(
              namespace: namespace,
              key: key,
              resource_type: product.class.name
            )

            next unless metafield_definition

            # Find existing metafield if product is persisted
            existing_metafield = product.persisted? ? product.metafields.find_by(metafield_definition: metafield_definition) : nil

            # Skip blank values for new metafields
            next if value.blank? && existing_metafield.nil?

            # For existing metafields with blank values, we'll mark them for destruction
            # For new metafields, we skip them (handled above)
            # For existing or new metafields with values, we create/update them
            metafield_attrs = {
              metafield_definition_id: metafield_definition.id,
              value: value.to_s.strip,
              type: metafield_definition.metafield_type
            }

            metafield_attrs[:id] = existing_metafield.id if existing_metafield

            nested_attrs << metafield_attrs
          end

          product.update(metafields_attributes: nested_attrs) unless nested_attrs.empty?
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
