module Spree
  module Imports
    module RowProcessors
      class ProductVariant < Base
        OPTION_TYPES_COUNT = 3

        def initialize(row, **)
          super
          @store = row.store
          @product = ensure_product_exists
        end

        attr_reader :product, :store

        def process!
          variant = if attributes['sku'].present?
                      product.variants.where(
                        Spree::Variant.arel_table[:sku].lower.eq(attributes['sku'].strip.downcase)
                      ).first || product.variants.new
                    elsif options.empty?
                      product.default_variant
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
          variant.option_value_variants = prepare_option_value_variants if options.any?

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
            variant.set_stock(attributes['inventory_count'].to_i, attributes['inventory_backorderable']&.to_b)
          end

          handle_images(variant)

          remove_placeholder_default_variant if options.any?

          # A row that resolves to a real option variant owns that Variant; a
          # product/header row resolves to the option-less default (a placeholder
          # that may later be removed), so it owns the Product instead — keeping the
          # import row linked to a record that always survives.
          variant.option_values.any? ? variant : product
        end

        private

        # A product-header (options-empty) row creates an option-less default
        # variant to hold product-level attributes. Once an option-bearing
        # variant exists, that placeholder is a leftover — remove it and
        # re-point the default so the product has exactly its option variants.
        def remove_placeholder_default_variant
          placeholders = product.variants.where.missing(:option_value_variants)
          return if placeholders.empty?

          placeholders.destroy_all
          product.update_column(:default_variant_id, product.variants.reload.first&.id)
        end

        def ensure_product_exists
          if options.empty?
            # For product/header rows (no options), create or update the product
            product = Spree::Product.new
            if attributes['slug'].present?
              existing_product = product_scope.find_by(slug: attributes['slug'].strip.downcase)
              product = existing_product if existing_product.present?
            end

            # Store is touched when the import completes
            Spree::Store.no_touching do
              product = assign_attributes_to_product(product)
              product.save!
            end

            handle_tags(product) if attributes['tags'].present?
            if has_product_attributes?
              handle_metafields(product)
              handle_categories(product)
            end

            product
          else
            # For variant rows (with options), only look up the product
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
          # set the SKU on a product/header row so process! updates the default variant instead of creating a new one
          if product.new_record?
            product.slug = attributes['slug']
            product.sku = attributes['sku'] if attributes['sku'].present? && options.empty?
            product.store = store
            # Publish to the store's default channel so imported products surface
            # in the storefront.
            product.channels << store.default_channel if store.default_channel && product.channels.empty?
          end

          product.name = attributes['name'] if attributes['name'].present?
          product.description = attributes['description'] if attributes['description'].present?
          product.meta_title = attributes['meta_title'] if attributes['meta_title'].present?
          product.meta_description = attributes['meta_description'] if attributes['meta_description'].present?
          product.meta_keywords = attributes['meta_keywords'] if attributes['meta_keywords'].present?
          product.status = to_spree_status(attributes['status']) if attributes['status'].present?

          if options.empty?
            if attributes['shipping_category'].present?
              shipping_category = prepare_shipping_category
              product.shipping_category = shipping_category if shipping_category.present?
            end
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

        def prepare_option_value_variants
          return [] if options.empty?

          ActiveRecord::Base.no_touching do
            options.map do |option|
              option_type = find_or_create_option_type!(option[:option_name])
              option_value = find_or_create_option_value!(option_type, option[:option_value])

              # ensure product option types include new option type
              find_or_create_product_option_type!(option_type)

              Spree::OptionValueVariant.new(option_value: option_value)
            end
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

        # Concurrent CSV imports can race when creating shared OptionTypes/OptionValues.
        # Recover the losing worker by re-fetching the peer's row whether the conflict
        # surfaces via the DB unique index (RecordNotUnique) or the AR uniqueness
        # validator (RecordInvalid with a :taken error on the relevant attribute).
        def find_or_create_option_type!(presentation)
          Spree::OptionType.search_by_name(presentation).first || Spree::OptionType.create!(presentation: presentation)
        rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
          raise unless uniqueness_conflict?(e, :name)

          Spree::OptionType.search_by_name(presentation).first!
        end

        def find_or_create_option_value!(option_type, presentation)
          option_type.option_values.search_by_name(presentation).first || option_type.option_values.create!(presentation: presentation)
        rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
          raise unless uniqueness_conflict?(e, :name)

          option_type.option_values.search_by_name(presentation).first!
        end

        def find_or_create_product_option_type!(option_type)
          Spree::ProductOptionType.find_or_create_by!(product: product, option_type: option_type)
        rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
          raise unless uniqueness_conflict?(e, :product_id)

          Spree::ProductOptionType.find_by!(product: product, option_type: option_type)
        end

        # RecordNotUnique is always a uniqueness conflict; RecordInvalid only when the
        # given attribute has a :taken error (other validation failures must propagate).
        def uniqueness_conflict?(error, attribute)
          error.is_a?(ActiveRecord::RecordNotUnique) || error.record.errors.where(attribute, :taken).any?
        end

        def handle_images(variant)
          image_urls = [
            attributes['image1_src'],
            attributes['image2_src'],
            attributes['image3_src'],
          ].compact.map(&:strip).compact_blank.uniq

          return if image_urls.empty?

          # Always attach to the product so blobs aren't duplicated across
          # variants. For option rows, pass the variant id so the job links the
          # resulting product-level asset to that variant via VariantMedia; a
          # simple product's default variant keeps images product-level.
          link_variant_id = options.empty? ? nil : variant.id

          image_urls.each do |image_url|
            Spree::Images::SaveFromUrlJob.perform_later(
              product.id,
              'Spree::Product',
              image_url,
              nil,
              nil,
              link_variant_id
            )
          end
        end

        def has_product_attributes?
          %w[name status description category1 category2 category3].any? { |key| attributes[key].present? }
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

        def handle_tags(product)
          Spree::Imports::AssignTagsJob.perform_later(product.id, attributes['tags'])
        end

        def handle_categories(product)
          Spree::Imports::CreateCategoriesJob.perform_later(product.id, store.id, prepare_taxon_pretty_names)
        end

        def prepare_taxon_pretty_names
          [
            attributes['category1'],
            attributes['category2'],
            attributes['category3']
          ].compact_blank.map(&:strip).uniq
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
