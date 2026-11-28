# The order timeline: one row per step taken on a placed order, written as it
# happens and never changed (docs/plans/6.1-order-timeline.md).
class CreateSpreeOrderActivities < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_order_activities do |t|
      t.references :order, null: false, index: false
      # The event that recorded it (`payment.completed`), or `comment`.
      t.string :kind, null: false
      t.string :category, null: false
      t.references :actor, polymorphic: true, index: { name: 'index_spree_order_activities_on_actor' }
      t.references :order_change
      t.text :body
      if t.respond_to?(:jsonb)
        t.jsonb :details
      else
        t.json :details
      end
      t.datetime :created_at, null: false
    end

    add_index :spree_order_activities, [:order_id, :created_at]
  end
end
