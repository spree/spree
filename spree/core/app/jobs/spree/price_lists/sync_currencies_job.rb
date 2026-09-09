module Spree
  module PriceLists
    # Gives every price list of a store the quantity-1 placeholder rows it is
    # missing in a currency the store started selling in after the list's
    # products were added.
    #
    # A list's membership is its price rows, and the price spreadsheet shows a
    # currency's products through the rows in that currency — so a currency
    # with no rows reads as a list with no products. `add_products` inserts
    # only the (variant, currency) rows that do not exist yet, which is what
    # makes this safe to run on every market change. A currency the store
    # stopped selling in keeps its rows: dropping prices a merchant typed is
    # not this job's call.
    #
    # A store with many lists is walked on a Continuation: the cursor is the
    # last list synced, so a deploy or a worker restart mid-run resumes with
    # the next list rather than starting the walk over. Each list's own write
    # is idempotent, so a list interrupted mid-insert is simply redone.
    class SyncCurrenciesJob < ::Spree::BaseJob
      include ActiveJob::Continuable

      # @param store_id [String, Integer]
      def perform(store_id)
        # Outside the step on purpose: runs on every execution, resumes included.
        @store = Spree::Store.find_by(id: store_id)
        return if @store.nil?

        step :sync_price_lists
      end

      private

      def sync_price_lists(step)
        @store.price_lists.find_each(start: step.cursor) do |price_list|
          product_ids = price_list.products.ids
          price_list.add_products(product_ids) if product_ids.any?
          step.advance! from: price_list.id
        end
      end
    end
  end
end
