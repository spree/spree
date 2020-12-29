class CreateSpreeRefunds < ActiveRecord::Migration[4.2]
  def change
    create_table :spree_refunds do |t|
      t.integer :payment_id
      t.integer :return_authorization_id
      t.decimal :amount, precision: 10, scale: 2, default: 0.0, null: false
      t.string :transaction_id

      t.timestamps null: false, precision: 6
    end
  end
end
