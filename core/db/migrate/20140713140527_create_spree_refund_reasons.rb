class CreateSpreeRefundReasons < ActiveRecord::Migration
  def change
    create_table :spree_refund_reasons do |t|
      t.string :name
      t.boolean :active, default: true
      t.boolean :mutable, default: true

      t.timestamps null: false
    end

    add_column :spree_refunds, :refund_reason_id, :integer
    add_index :spree_refunds, :refund_reason_id, name: 'index_refunds_on_refund_reason_id'
  end
end
