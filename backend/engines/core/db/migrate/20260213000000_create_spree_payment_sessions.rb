class CreateSpreePaymentSessions < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_payment_sessions do |t|
      t.string :type, null: false, index: true
      t.references :order, null: false, index: true
      t.references :payment_method, null: false, index: true
      t.references :customer, index: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :currency, null: false
      t.string :status, null: false, index: true
      t.string :external_id, null: false
      if t.respond_to? :jsonb
        t.jsonb :external_data, default: {}
      else
        t.json :external_data, default: {}
      end
      t.datetime :expires_at, index: true
      t.string :customer_external_id
      t.datetime :deleted_at, index: true
      t.timestamps
    end

    add_index :spree_payment_sessions, [:order_id, :payment_method_id, :external_id],
              unique: true, name: 'idx_payment_sessions_order_method_external'
    add_index :spree_payment_sessions, :external_id
  end
end
