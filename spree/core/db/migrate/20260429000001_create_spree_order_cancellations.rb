class CreateSpreeOrderCancellations < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_order_cancellations do |t|
      t.references :order, null: false, index: false
      t.string :reason, null: false
      t.text :note
      t.boolean :restock_items, null: false
      t.boolean :refund_payments, null: false
      t.decimal :refund_amount, precision: 10, scale: 2
      t.boolean :notify_customer, null: false
      t.references :canceled_by, polymorphic: true, index: false
      if t.respond_to? :jsonb
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.timestamps
    end

    add_index :spree_order_cancellations, :order_id
    add_index :spree_order_cancellations, [:canceled_by_id, :canceled_by_type],
              name: 'idx_order_cancellations_canceled_by'
    add_index :spree_order_cancellations, :created_at
  end
end
