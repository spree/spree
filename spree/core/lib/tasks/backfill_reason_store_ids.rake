namespace :spree do
  namespace :upgrade do
    desc <<~DESC
      Assigns the default store to return and refund reasons that predate
      their store binding (Spree 6.0). Idempotent — rows that already carry a
      store_id are skipped.

      Run this immediately after db:migrate. Core looks three refund reasons
      up by name (RefundReason::RETURN_PROCESSING_REASON and friends) scoped
      to a store, so until every row carries one those lookups miss and mint
      a duplicate on the next refund.

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
