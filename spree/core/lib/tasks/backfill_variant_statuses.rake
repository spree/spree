namespace :spree do
  namespace :upgrade do
    desc <<~DESC
      Fills in the new status column on variants that predate it (Spree 6.0),
      setting every one to `active`. Idempotent — rows that already carry a
      status are skipped, so an interrupted run resumes for free.

      Spree 6.0 gives a variant its own review lifecycle so a seller's offer on
      a shared master-catalog product can be submitted, approved and sent back
      (docs/plans/6.0-seller-master-catalog-listings.md). Every variant that
      existed before that was on sale, so `active` is what they were.

      This matters because `active` now gates availability: a variant with no
      status answers `active?` false, which would take the whole existing
      catalog off sale. Run it before serving traffic on the new code.
    DESC
    task backfill_variant_statuses: :environment do
      # Batched by primary key rather than `limit` on the update: MySQL
      # refuses LIMIT on a multi-table-capable UPDATE, and a single statement
      # over a large catalog would hold one long write lock.
      total = 0

      Spree::Variant.unscoped.where(status: nil).in_batches(of: 10_000) do |batch|
        total += batch.update_all(status: 'active')
        puts "  Backfilled #{total} variant(s)..."
      end

      puts "  Set status to 'active' on #{total} variant(s)."
    end
  end
end
