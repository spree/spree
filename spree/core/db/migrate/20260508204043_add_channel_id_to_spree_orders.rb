class AddChannelIdToSpreeOrders < ActiveRecord::Migration[7.2]
  # Non-destructive: adds the FK column alongside the existing `channel`
  # string column. Old reads keep working until the upgrade rake task
  # `spree:order_routing:backfill_channel_ids` populates `channel_id`.
  # The string column is dropped in a follow-up migration once the
  # backfill has run.
  def change
    add_reference :spree_orders, :channel
  end
end
