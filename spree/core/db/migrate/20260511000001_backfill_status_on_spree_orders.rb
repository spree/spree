class BackfillStatusOnSpreeOrders < ActiveRecord::Migration[7.2]
  BATCH_SIZE = 10_000

  STATE_TO_STATUS = {
    'placed'   => %w[complete resumed returned awaiting_return],
    'canceled' => %w[canceled partially_canceled]
  }.freeze

  def up
    STATE_TO_STATUS.each do |target_status, states|
      backfill_in_batches(target_status, states)
    end

    # Anything still NULL (carts, in-progress checkouts) becomes draft.
    backfill_in_batches('draft', nil)

    change_column_default :spree_orders, :status, 'draft'
    change_column_null    :spree_orders, :status, false
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          'Backfilled status values cannot be safely restored: writes made after deploy ' \
          'are indistinguishable from the backfill. Roll back manually if needed.'
  end

  private

  def backfill_in_batches(target_status, source_states)
    quoted_status = connection.quote(target_status)
    state_filter =
      if source_states
        quoted = Array(source_states).map { |s| connection.quote(s) }.join(',')
        "AND state IN (#{quoted})"
      else
        ''
      end

    loop do
      # The nested SELECT wrap (`SELECT id FROM (SELECT id ... LIMIT N) AS t`) is
      # required for MySQL, which refuses an UPDATE that selects from the same
      # table in the WHERE clause without an intermediate derived table.
      affected = connection.update(<<~SQL.squish)
        UPDATE spree_orders SET status = #{quoted_status}
         WHERE id IN (
           SELECT id FROM (
             SELECT id FROM spree_orders
              WHERE status IS NULL #{state_filter}
              LIMIT #{BATCH_SIZE}
           ) AS spree_orders_batch
         )
      SQL

      break if affected < BATCH_SIZE
    end
  end
end
