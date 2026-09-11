module Spree
  # Turns 5.x "external receive" stock transfers into purchase orders.
  #
  # A supplier receive was never a transfer: it has a cost, a supplier and an
  # expected date, none of which moving stock between two of the merchant's own
  # warehouses has (docs/plans/6.0-inventory-operations.md). Each source-less
  # transfer becomes a Spree::PurchaseOrder against a "Migrated receives"
  # supplier, its existing movements are re-pointed at the new order, and the
  # transfer is soft-deleted so its number stays readable.
  #
  # Stock is never touched: those movements already moved it, at the time.
  class ExternalReceivesMigrator
    # Historical unit costs are unknowable — nothing recorded them.
    UNKNOWN_UNIT_COST = 0
    SUPPLIER_NAME = 'Migrated receives'.freeze

    def initialize(output: $stdout)
      @output = output
      @migrated = 0
      @skipped = 0
    end

    def call
      pending.find_each { |transfer| migrate_one(transfer) }
      backfilled = backfill_internal_transfers

      @output.puts "  Migrated #{@migrated} external receive(s), skipped #{@skipped}."
      @output.puts "  Backfilled store and status on #{backfilled} internal transfer(s)."
    end

    private

    # Only live, source-less rows. A previous run's output is soft-deleted, so
    # re-running picks up just what it could not reach.
    def pending
      Spree::StockTransfer.where(source_location_id: nil)
    end

    def migrate_one(transfer)
      destination = transfer.destination_location

      if destination.nil? || destination.store.nil?
        skip(transfer, 'its destination location has no store')
        return
      end

      Spree::StockTransfer.transaction do
        movements = transfer.stock_movements.to_a
        purchase_order = build_purchase_order(transfer, destination, movements)

        # A receive whose movements no longer resolve to a variant has nothing
        # to order; the transfer is left for a human to look at.
        if purchase_order.items.empty?
          skip(transfer, 'no stock movements to build lines from')
          raise ActiveRecord::Rollback
        end

        # A legacy receive whose movements cancel out to zero for a variant
        # cannot become a line, and must not take the rest of the run with it.
        unless purchase_order.save
          skip(transfer, purchase_order.errors.full_messages.join(', '))
          raise ActiveRecord::Rollback
        end

        receipt = mint_receipt(purchase_order, transfer)
        Spree::StockMovement.where(id: movements.map(&:id)).update_all(
          purchase_order_id: purchase_order.id,
          stock_receipt_id: receipt.id
        )
        transfer.update_columns(status: 'received', deleted_at: Time.current)

        @output.puts "  #{transfer.number} → #{purchase_order.number} (#{purchase_order.items.size} line(s))"
        @migrated += 1
      end
    end

    def build_purchase_order(transfer, destination, movements)
      store = destination.store

      purchase_order = store.purchase_orders.new(
        supplier: supplier_for(store),
        destination_location: destination,
        currency: store.default_currency,
        status: 'received',
        received_at: transfer.created_at,
        reference: transfer.reference.presence || transfer.number,
        notes: "Migrated from stock transfer #{transfer.number}."
      )

      lines_from(movements).each do |variant_id, quantity|
        purchase_order.items.build(
          variant_id: variant_id,
          quantity_ordered: quantity,
          quantity_received: quantity,
          unit_cost: UNKNOWN_UNIT_COST
        )
      end

      purchase_order
    end

    # The receive itself, as the record every later delivery gets: one
    # receipt, dated when the transfer was, accepting every line in full.
    def mint_receipt(purchase_order, transfer)
      receipt = purchase_order.stock_receipts.build(
        store: purchase_order.store,
        received_at: transfer.created_at,
        reference: transfer.number,
        notes: "Migrated from stock transfer #{transfer.number}."
      )
      purchase_order.items.each do |item|
        receipt.items.build(line: item, quantity_accepted: item.quantity_received)
      end
      receipt.save!
      receipt
    end

    # One line per variant, summing the movements that named it: a 5.x receive
    # of five SKUs is five movement rows whose only link is the transfer.
    #
    # Signed, so rows that offset each other total what they actually moved.
    # A variant summing to zero is dropped — it received nothing, and a line
    # of zero would fail validation and take the whole transfer with it. A
    # negative total is left alone deliberately: the line then refuses to
    # validate and the transfer is skipped for someone to look at, which is
    # the right answer for a receive that reads as a dispatch.
    def lines_from(movements)
      totals = movements.each_with_object({}) do |movement, lines|
        variant_id = movement.stock_level&.variant_id
        next if variant_id.nil?

        lines[variant_id] = lines.fetch(variant_id, 0) + movement.quantity
      end

      totals.reject { |_variant_id, quantity| quantity.zero? }
    end

    def supplier_for(store)
      @suppliers ||= {}
      @suppliers[store.id] ||= store.suppliers.find_or_create_by!(name: SUPPLIER_NAME) do |supplier|
        supplier.notes = 'Created by spree:upgrade:migrate_external_receives_to_purchase_orders ' \
                         'to own receives that predate purchase orders.'
      end
    end

    # Every 5.x transfer moved its stock the instant it was created, so it is
    # retroactively a completed one — which is what today's reality already is.
    def backfill_internal_transfers
      scope = Spree::StockTransfer.where(status: nil).or(Spree::StockTransfer.where(store_id: nil))
      count = 0

      scope.includes(:destination_location).find_each do |transfer|
        store_id = transfer.store_id || transfer.destination_location&.store_id
        next if store_id.nil?

        transfer.update_columns(
          store_id: store_id,
          status: transfer.status || 'received',
          received_at: transfer.received_at || transfer.created_at
        )
        count += 1
      end

      count
    end

    def skip(transfer, reason)
      @output.puts "  Skipping transfer #{transfer.number}: #{reason}."
      @skipped += 1
    end
  end
end

namespace :spree do
  namespace :upgrade do
    desc <<~DESC
      Converts 5.x "external receive" stock transfers — the ones with no source
      location — into purchase orders, and gives every other transfer the store
      and status the 6.0 lifecycle expects.

      The original transfer is soft-deleted so its T-… number stays findable
      for historical reporting without the same receive appearing twice in the
      admin. Purge them with spree:upgrade:purge_migrated_external_receives
      once nobody needs the old numbers.

      Idempotent: stock is never touched, and a transfer already migrated is
      out of scope on the next run.
    DESC
    task migrate_external_receives_to_purchase_orders: :environment do
      Spree::ExternalReceivesMigrator.new.call
    end

    desc <<~DESC
      Deletes the stock transfers that
      spree:upgrade:migrate_external_receives_to_purchase_orders soft-deleted,
      once their T-… numbers are no longer needed.

      Only source-less, soft-deleted rows whose movements now belong to a
      purchase order are removed — a transfer still owning its ledger is left
      alone.
    DESC
    task purge_migrated_external_receives: :environment do
      still_owning_movements = Spree::StockMovement.where(purchase_order_id: nil).
                              where.not(stock_transfer_id: nil).select(:stock_transfer_id)

      migrated = Spree::StockTransfer.only_deleted.
                 where(source_location_id: nil).
                 where.not(id: still_owning_movements)

      count = 0
      migrated.find_each do |transfer|
        # The movements kept naming the transfer for lineage while it was only
        # soft-deleted. It is about to stop existing, so that reference has to
        # go with it rather than becoming an id that resolves to nothing.
        Spree::StockMovement.where(stock_transfer_id: transfer.id).update_all(stock_transfer_id: nil)
        transfer.really_destroy!
        count += 1
      end

      puts "  Purged #{count} migrated external receive(s)."
    end
  end
end
