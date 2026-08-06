namespace :spree do
  namespace :upgrade do
    desc <<~DESC
      Assigns the default store to return and refund reasons that predate
      their store binding (Spree 6.0). Idempotent — rows that already carry a
      store_id are skipped.

      The rename migration already backfills and then enforces NOT NULL, so
      this is a safety net rather than the primary path: it covers installs
      whose migration ran before any store existed, leaving rows unowned and
      the constraint unapplied. Running it on an already-migrated store is a
      no-op.

      Claim reasons need no backfill — the table is new in 6.0 and its rows
      are born with a store.
    DESC
    task backfill_reason_store_ids: :environment do
      store = Spree::Store.default
      abort '  No default store found — create a store first.' if store.nil?

      return_reasons = Spree::ReturnReason.where(store_id: nil).update_all(store_id: store.id)
      refund_reasons = Spree::RefundReason.where(store_id: nil).update_all(store_id: store.id)

      puts "  Assigned #{return_reasons} return reason(s) and #{refund_reasons} refund reason(s) " \
           "to store #{store.name} (#{store.id})."
    end
  end
end
