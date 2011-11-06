class DeletedAtForPaymentMethods < ActiveRecord::Migration
  def up
    change_table :payment_methods do |t|
      t.timestamp :deleted_at, :default => nil
    end
  end

  def down
    remove_column :payments_methods, :column_name
    change_table :payment_methods do |t|
      t.remove :deleted_at
    end
  end
end