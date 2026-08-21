class CreateSpreeOrderGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_order_groups do |t|
      t.references :store, null: false
      t.references :customer, index: true # guest checkouts have no customer
      # The cart this group was completed from. Unique for the same reason
      # orders.cart_id is: it is the completion idempotency key, so a replayed
      # completion finds the group instead of building a second one.
      t.references :cart, index: { unique: true }

      t.string :number, null: false
      t.string :currency, null: false
      # Guest checkouts carry the contact address here, as the order does.
      t.string :email
      t.string :token

      t.references :ship_address
      t.references :bill_address

      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end

      t.timestamps
    end

    add_index :spree_order_groups, :number, unique: true
    add_index :spree_order_groups, [:store_id, :created_at]
    add_index :spree_order_groups, :token
  end
end
