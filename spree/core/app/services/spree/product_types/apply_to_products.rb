module Spree
  module ProductTypes
    # Backfills a product type's option types and categories onto the products
    # that already carry the type. This is the only path from a type edit to
    # existing products — ordinary type edits leave products untouched.
    #
    # Additive and idempotent: products keep everything they already have, so a
    # re-run after a crash is safe.
    class ApplyToProducts
      prepend ::Spree::ServiceModule::Base

      BATCH_SIZE = 500

      # @param product_type [Spree::ProductType]
      # @return [Spree::ServiceModule::Base::Result] count of products changed
      def call(product_type:)
        option_types = product_type.option_types.to_a
        categories = product_type.categories.to_a

        return success(0) if option_types.empty? && categories.empty?

        changed_product_ids = Set.new

        product_type.products.find_in_batches(batch_size: BATCH_SIZE) do |products|
          changed_product_ids.merge(add_option_types(products, option_types))
          changed_product_ids.merge(add_categories(products, categories))
        end

        success(changed_product_ids.size)
      end

      private

      # @return [Array] ids of products that gained at least one option type
      def add_option_types(products, option_types)
        return [] if option_types.empty?

        product_ids = products.map(&:id)
        option_type_ids = option_types.map(&:id)

        existing = Spree::ProductOptionType.where(product_id: product_ids, option_type_id: option_type_ids).
                   pluck(:product_id, :option_type_id).to_set

        # acts_as_list scopes position per product, so continue each product's
        # own sequence rather than restarting at 1.
        highest_positions = Spree::ProductOptionType.where(product_id: product_ids).
                            group(:product_id).maximum(:position)

        rows = product_ids.flat_map do |product_id|
          position = highest_positions[product_id].to_i

          option_type_ids.filter_map do |option_type_id|
            next if existing.include?([product_id, option_type_id])

            position += 1
            { product_id: product_id, option_type_id: option_type_id, position: position,
              created_at: Time.current, updated_at: Time.current }
          end
        end

        return [] if rows.empty?

        Spree::ProductOptionType.insert_all(rows)
        rows.pluck(:product_id).uniq
      end

      # Delegates to the bulk category service, which owns the counter-cache,
      # position and search-index bookkeeping that insert_all would skip.
      #
      # @return [Array] ids of products that gained at least one category
      def add_categories(products, categories)
        return [] if categories.empty?

        product_ids = products.map(&:id)
        linked = Spree::ProductCategory.where(product_id: product_ids, category_id: categories.map(&:id)).
                 pluck(:category_id, :product_id).group_by(&:first)

        changed_product_ids = []

        categories.each do |category|
          already_linked = linked.fetch(category.id, []).map(&:last).to_set
          missing = products.reject { |product| already_linked.include?(product.id) }
          next if missing.empty?

          missing_ids = missing.map(&:id)
          Spree::Categories::AddProducts.call(
            categories: Spree::Category.where(id: category.id),
            products: Spree::Product.where(id: missing_ids)
          )
          changed_product_ids.concat(missing_ids)
        end

        changed_product_ids.uniq
      end
    end
  end
end
