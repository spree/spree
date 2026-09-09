class ReplaceOrderCancellationTablesWithCancelColumns < ActiveRecord::Migration[8.1]
  def up
    # Checked explicitly rather than with `if_not_exists: true`: that option
    # skips the CREATE TABLE but still emits the index statements the block
    # declares, which then fail against a table that lacks those columns.
    unless table_exists?(:spree_order_cancellation_reasons)
      create_table :spree_order_cancellation_reasons do |t|
        t.string :name, null: false
        t.references :store, null: false
        t.boolean :active, null: false, default: true
        if t.respond_to?(:jsonb)
          t.jsonb :metadata
        else
          t.json :metadata
        end
        t.timestamps
      end
    end

    add_index :spree_order_cancellation_reasons, [:store_id, :name], unique: true,
              name: 'idx_order_cancellation_reasons_on_store_and_name', if_not_exists: true

    add_reference :spree_orders, :cancel_reason, index: true unless column_exists?(:spree_orders, :cancel_reason_id)
    add_column :spree_orders, :cancel_note, :text unless column_exists?(:spree_orders, :cancel_note)

    # Nothing ever read these tables: no API, admin view, mail or export
    # consulted a row, and every row written carried the default reason.
    drop_table :spree_order_cancellations, if_exists: true
    drop_table :spree_order_approvals, if_exists: true
  end

  # Restores the two dropped tables as well as undoing this migration's own
  # additions. The migrations that created them are deleted in this same
  # change, so nothing else can put them back — without this, a rollback
  # would leave a schema with neither the old tables nor the new columns.
  # Their rows are gone either way: they were write-only, so there is nothing
  # to preserve.
  def down
    unless table_exists?(:spree_order_cancellations)
      create_table :spree_order_cancellations do |t|
        t.references :order, null: false, index: false
        t.string :reason, null: false
        t.text :note
        t.boolean :restock_items, null: false
        t.boolean :refund_payments, null: false
        t.decimal :refund_amount, precision: 10, scale: 2
        t.boolean :notify_customer, null: false
        t.references :canceled_by, polymorphic: true, index: false
        if t.respond_to?(:jsonb)
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

    unless table_exists?(:spree_order_approvals)
      create_table :spree_order_approvals do |t|
        t.references :order, null: false, index: false
        t.string :status, null: false
        t.string :level
        t.text :note
        t.references :approver, polymorphic: true, index: false
        t.datetime :decided_at
        if t.respond_to?(:jsonb)
          t.jsonb :metadata
        else
          t.json :metadata
        end
        t.timestamps
      end

      add_index :spree_order_approvals, [:order_id, :status]
      add_index :spree_order_approvals, [:approver_id, :approver_type],
                name: 'idx_order_approvals_approver'
    end

    remove_column :spree_orders, :cancel_note, if_exists: true
    remove_reference :spree_orders, :cancel_reason, if_exists: true
    drop_table :spree_order_cancellation_reasons, if_exists: true
  end
end
