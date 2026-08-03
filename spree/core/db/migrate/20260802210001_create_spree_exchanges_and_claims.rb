class CreateSpreeExchangesAndClaims < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_exchanges do |t|
      t.string :number, null: false
      t.references :store, null: false
      t.references :order, null: false
      t.references :stock_location, null: false
      t.references :reason
      t.references :created_by
      t.string :status, null: false
      t.text :memo
      t.datetime :approved_at
      t.datetime :received_at
      t.datetime :fulfilled_at
      t.datetime :canceled_at
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.timestamps
    end

    add_index :spree_exchanges, :number, unique: true
    add_index :spree_exchanges, :status

    create_table :spree_exchange_line_items do |t|
      t.references :exchange, null: false
      t.references :fulfillment_item, null: false
      t.references :line_item, null: false
      # The variant coming back and the one going out — an exchange is a
      # swap, so both sides live on the row.
      t.references :original_variant, null: false
      t.references :new_variant, null: false
      t.integer :quantity, null: false, default: 1
      t.integer :received_quantity, null: false, default: 0
      t.boolean :resellable, null: false, default: true
      t.timestamps
    end

    create_table :spree_claims do |t|
      t.string :number, null: false
      t.references :store, null: false
      t.references :order, null: false
      t.references :reason
      t.references :created_by
      t.string :status, null: false
      t.string :claim_type, null: false
      t.string :resolution
      t.text :memo
      t.datetime :approved_at
      t.datetime :resolved_at
      t.datetime :denied_at
      t.datetime :canceled_at
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.timestamps
    end

    add_index :spree_claims, :number, unique: true
    add_index :spree_claims, :status

    create_table :spree_claim_line_items do |t|
      t.references :claim, null: false
      t.references :line_item, null: false
      t.references :variant, null: false
      # Optional: a replacement may be a different variant, or none at all
      # when the claim is resolved with money only.
      t.references :replacement_variant
      t.integer :quantity, null: false, default: 1
      t.boolean :send_replacement, null: false, default: false
      t.decimal :refund_amount, precision: 10, scale: 2, null: false, default: 0
      t.text :description
      t.timestamps
    end
  end
end
