class CreateSpreeReturns < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_returns do |t|
      t.string :number, null: false
      t.references :store, null: false
      t.references :order, null: false
      t.references :stock_location, null: false
      t.references :reason
      # Staff only — customer-initiated returns leave this nil, the
      # requester is always order.customer.
      t.references :created_by
      t.string :status, null: false
      t.text :memo
      t.string :return_label_url
      t.datetime :approved_at
      t.datetime :received_at
      t.datetime :refunded_at
      t.datetime :canceled_at
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.timestamps
    end

    add_index :spree_returns, :number, unique: true
    add_index :spree_returns, :status

    create_table :spree_return_line_items do |t|
      t.references :return, null: false
      t.references :fulfillment_item, null: false
      t.references :line_item, null: false
      t.references :variant, null: false
      t.integer :quantity, null: false, default: 1
      t.integer :received_quantity, null: false, default: 0
      t.decimal :pre_tax_amount, precision: 10, scale: 2, null: false, default: 0
      t.boolean :resellable, null: false, default: true
      t.timestamps
    end

    # Who triggered a refund: a Return, and later an Exchange or Claim.
    # Small closed set, never bulk-queried in a hot path — the one
    # intentional polymorphic association in this area.
    add_column :spree_refunds, :originator_type, :string
    add_column :spree_refunds, :originator_id, :bigint
    add_index :spree_refunds, [:originator_type, :originator_id],
              name: 'index_spree_refunds_on_originator'
  end
end
