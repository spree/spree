module Spree
  module ProductTypes
    # Backfills a product type's option types and categories onto its existing
    # products, on ActiveJob Continuations: the cursor is the last product id
    # applied, so a deploy or timeout mid-backfill resumes from there instead of
    # restarting a catalog-sized run.
    #
    # Products are walked in id order — a stable ordering is what makes the
    # cursor meaningful, unlike `find_in_batches`' batching alone. Each batch is
    # additive and idempotent, so re-running the batch that was in flight when
    # the job died changes nothing.
    class ApplyToProductsJob < ::Spree::BaseJob
      include ActiveJob::Continuable

      queue_as Spree.queues.products

      def perform(product_type_id)
        # Outside the steps on purpose — runs on every execution, resumes
        # included.
        @product_type = Spree::ProductType.find_by(id: product_type_id)
        return if @product_type.nil?

        service = Spree::ProductTypes::ApplyToProducts.new
        return if service.nothing_to_apply?(@product_type)

        step :apply_to_products, start: 0
        step :settle_bookkeeping
      end

      private

      # Cursor = the highest product id already applied. Checkpointed after each
      # batch, so a resume re-reads nothing it has finished.
      def apply_to_products(step)
        service = Spree::ProductTypes::ApplyToProducts.new

        loop do
          product_ids = @product_type.products.where(Spree::Product.arel_table[:id].gt(step.cursor)).
                        order(:id).limit(Spree::ProductTypes::ApplyToProducts::BATCH_SIZE).pluck(:id)
          break if product_ids.empty?

          service.apply_batch(@product_type, product_ids)
          step.set!(product_ids.last)
        end
      end

      # Counter caches, branch counts and reindexing settle once for the whole
      # run — each is a subtree-wide recount or a job per product, so doing it
      # per batch would cost more than the backfill itself.
      #
      # The set of touched products is re-derived from the join table rather
      # than carried across batches: a resumed job has no memory of what earlier
      # executions changed, and every product of the type is in the right state
      # by now regardless of which execution put it there.
      def settle_bookkeeping
        category_ids = @product_type.category_ids
        return if category_ids.empty?

        service = Spree::ProductTypes::ApplyToProducts.new
        store = @product_type.store

        # Per-product counters batch — the whole point of the cursor is not
        # holding a catalog-sized id list in memory.
        @product_type.products.select(:id).
          find_in_batches(batch_size: Spree::ProductTypes::ApplyToProducts::BATCH_SIZE) do |products|
          service.settle_product_counters(store, products.map(&:id))
        end

        # The subtree-wide category recount runs once.
        service.settle_category_counters(store, category_ids)
      end
    end
  end
end
