module Spree
  module ProductTypes
    # Backfills a product type's option types and categories onto the products
    # that already carry the type. This is the only path from a type edit to
    # existing products — ordinary type edits leave products untouched.
    #
    # Additive and idempotent: products keep everything they already have, so a
    # re-run after a crash is safe.
    #
    # `ApplyToProductsJob` drives this in id order with a resumable cursor, so
    # the entry points are deliberately separate: {#call} runs the whole
    # backfill in one pass (console, specs, small catalogs), while
    # {#apply_batch} plus {#settle_product_counters} / {#settle_category_counters}
    # let the job checkpoint between batches.
    class ApplyToProducts
      prepend ::Spree::ServiceModule::Base

      BATCH_SIZE = 500

      # @param product_type [Spree::ProductType]
      # @return [Spree::ServiceModule::Base::Result] count of products changed
      def call(product_type:)
        return success(0) if nothing_to_apply?(product_type)

        store = product_type.store
        changed_product_ids = Set.new
        categorized_product_ids = Set.new

        # Only ids are ever needed — hydrating products would run their
        # after_initialize callbacks for nothing.
        product_type.products.select(:id).find_in_batches(batch_size: BATCH_SIZE) do |products|
          result = apply_batch(product_type, products.map(&:id))
          changed_product_ids.merge(result[:changed_ids])
          categorized_product_ids.merge(result[:categorized_ids])
        end

        settle_category_bookkeeping(store, categorized_product_ids.to_a, product_type.category_ids)

        success(changed_product_ids.size)
      end

      # @return [Boolean] true when the type defines nothing to seed
      def nothing_to_apply?(product_type)
        product_type.option_type_ids.empty? && product_type.category_ids.empty?
      end

      # One batch of the backfill. Split out so the job can checkpoint between
      # batches; safe to re-run on the same ids after an interruption.
      #
      # @return [Hash] :changed_ids and :categorized_ids for this batch
      def apply_batch(product_type, product_ids)
        store = product_type.store
        # Only ids that belong to this store — a type pointing at another
        # store's category must not drag it onto a product.
        category_ids = Spree::Category.for_store(store).where(id: product_type.category_ids).ids

        changed = add_option_types(store, product_ids, product_type.option_type_ids)
        categorized = add_categories(store, product_ids, category_ids)

        { changed_ids: changed | categorized, categorized_ids: categorized }
      end

      # insert_all skips the ProductCategory callbacks, so the per-product
      # counts they maintain are recomputed here. Safe to call per batch.
      def settle_product_counters(store, product_ids)
        return if product_ids.empty?

        products = store.products.where(id: product_ids)
        counts = Spree::ProductCategory.where(product_id: products.select(:id)).group(:product_id).count
        counts.each do |product_id, count|
          store.products.where(id: product_id).update_all(categories_count: count)
        end

        products.find_each(&:enqueue_search_index)
      end

      # The category side settles once for the whole run: `products_count` is a
      # subtree-wide recount over each category and its ancestors, so repeating
      # it per batch would cost more than the backfill.
      def settle_category_counters(store, category_ids)
        return if category_ids.empty?

        categories = Spree::Category.for_store(store).where(id: category_ids)
        Spree::Category.recalculate_products_count(categories.ids)
        categories.touch_all
      end

      # Both halves, for callers that run the backfill in one pass.
      def settle_category_bookkeeping(store, product_ids, category_ids)
        settle_product_counters(store, product_ids)
        settle_category_counters(store, category_ids) if product_ids.any?
      end

      private

      # @return [Array] ids of products that gained at least one option type
      def add_option_types(store, product_ids, option_type_ids)
        return [] if option_type_ids.empty?

        # Ids come from the type's own products, but re-scoping through the
        # store keeps a stale or cross-store id from reaching an insert.
        scoped_ids = store.products.where(id: product_ids).ids
        return [] if scoped_ids.empty?

        existing = Spree::ProductOptionType.where(product_id: scoped_ids, option_type_id: option_type_ids).
                   pluck(:product_id, :option_type_id).to_set

        # acts_as_list scopes position per product, so continue each product's
        # own sequence rather than restarting at 1.
        highest_positions = Spree::ProductOptionType.where(product_id: scoped_ids).
                            group(:product_id).maximum(:position)

        now = Time.current
        rows = scoped_ids.flat_map do |product_id|
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
      def add_categories(store, product_ids, category_ids)
        return [] if category_ids.empty?

        scoped_ids = store.products.where(id: product_ids).ids
        return [] if scoped_ids.empty?

        existing = Spree::ProductCategory.where(product_id: scoped_ids, category_id: category_ids).
                   pluck(:product_id, :category_id).to_set

        # acts_as_list scopes position per category here (unlike option types,
        # which scope per product), so each category continues its own sequence.
        highest_positions = Spree::ProductCategory.where(category_id: category_ids).
                            group(:category_id).maximum(:position)

        now = Time.current
        rows = category_ids.flat_map do |category_id|
          position = highest_positions[category_id].to_i

          scoped_ids.filter_map do |product_id|
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
    end
  end
end
