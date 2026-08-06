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
        option_type_ids = product_type.option_type_ids
        category_ids = product_type.category_ids

        return success(0) if option_type_ids.empty? && category_ids.empty?

        changed_product_ids = Set.new
        categorized_product_ids = Set.new

        # Only ids are ever needed — hydrating products would run their
        # after_initialize callbacks for nothing.
        product_type.products.select(:id).find_in_batches(batch_size: BATCH_SIZE) do |products|
          product_ids = products.map(&:id)

          changed_product_ids.merge(add_option_types(product_ids, option_type_ids))

          newly_categorized = add_categories(product_ids, category_ids)
          categorized_product_ids.merge(newly_categorized)
          changed_product_ids.merge(newly_categorized)
        end

        # Counter caches, branch counts and reindexing are settled once for the
        # whole run rather than per category per batch — each is a subtree-wide
        # recount or a job per product.
        settle_category_bookkeeping(categorized_product_ids.to_a, category_ids)

        success(changed_product_ids.size)
      end

      private

      # @return [Array] ids of products that gained at least one option type
      def add_option_types(product_ids, option_type_ids)
        return [] if option_type_ids.empty?

        existing = Spree::ProductOptionType.where(product_id: product_ids, option_type_id: option_type_ids).
                   pluck(:product_id, :option_type_id).to_set

        # acts_as_list scopes position per product, so continue each product's
        # own sequence rather than restarting at 1.
        highest_positions = Spree::ProductOptionType.where(product_id: product_ids).
                            group(:product_id).maximum(:position)

        now = Time.current
        rows = product_ids.flat_map do |product_id|
          position = highest_positions[product_id].to_i

          option_type_ids.filter_map do |option_type_id|
            next if existing.include?([product_id, option_type_id])

            position += 1
            { product_id: product_id, option_type_id: option_type_id, position: position,
              created_at: now, updated_at: now }
          end
        end

        return [] if rows.empty?

        Spree::ProductOptionType.insert_all(rows)
        rows.pluck(:product_id).uniq
      end

      # @return [Array] ids of products that gained at least one category
      def add_categories(product_ids, category_ids)
        return [] if category_ids.empty?

        existing = Spree::ProductCategory.where(product_id: product_ids, category_id: category_ids).
                   pluck(:product_id, :category_id).to_set

        # acts_as_list scopes position per category here (unlike option types,
        # which scope per product), so each category continues its own sequence.
        highest_positions = Spree::ProductCategory.where(category_id: category_ids).
                            group(:category_id).maximum(:position)

        now = Time.current
        rows = category_ids.flat_map do |category_id|
          position = highest_positions[category_id].to_i

          product_ids.filter_map do |product_id|
            next if existing.include?([product_id, category_id])

            position += 1
            { product_id: product_id, category_id: category_id, position: position,
              created_at: now, updated_at: now }
          end
        end

        return [] if rows.empty?

        Spree::ProductCategory.insert_all(rows)
        rows.pluck(:product_id).uniq
      end

      # insert_all skips the ProductCategory callbacks, so the counts they
      # maintain are recomputed here — once, for every product touched.
      def settle_category_bookkeeping(product_ids, category_ids)
        return if product_ids.empty?

        counts = Spree::ProductCategory.where(product_id: product_ids).group(:product_id).count
        counts.each do |product_id, count|
          Spree::Product.where(id: product_id).update_all(categories_count: count)
        end

        Spree::Category.recalculate_products_count(category_ids)
        Spree::Category.where(id: category_ids).touch_all

        Spree::Product.where(id: product_ids).find_each(&:enqueue_search_index)
      end
    end
  end
end
