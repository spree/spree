module Spree
  module MaintenanceTasks
    # Applies a price list supplied as a CSV — the correction an operator
    # reaches for after a bad import or a supplier price change
    # (docs/plans/6.0-maintenance-tasks.md).
    #
    # Expects `sku` and `price` columns; `currency` is optional and falls back
    # to the store's own. Rows naming an unknown SKU are counted and skipped
    # rather than failing the run, because a spreadsheet assembled by hand
    # routinely carries a few rows that no longer match the catalog, and
    # stopping on the first would make the task useless for the case it exists
    # to serve.
    #
    # This is also the reference CSV task: it is what an extension author
    # copies when their own task needs a file rather than a query.
    class UpdateVariantPrices < Spree::MaintenanceTask
      description 'maintenance_tasks.update_variant_prices.description'
      csv_collection
      supports_dry_run
      collection_batch_size 250

      def process(row)
        sku = row['sku'].to_s.strip
        amount = row['price'].to_s.strip

        return tally(:skipped_blank_row) if sku.blank? || amount.blank?

        variant = Spree::Variant.find_by(sku: sku)
        return tally(:skipped_unknown_sku) if variant.nil?

        currency = row['currency'].presence || variant.product.store&.default_currency
        price = variant.prices.find_or_initialize_by(currency: currency)

        if dry_run?
          tally(price.persisted? ? :would_update : :would_create)
          return
        end

        price.amount = amount
        price.save!

        tally(price.previously_new_record? ? :created : :updated)
      end
    end
  end
end
