class CreateDiscounts < ActiveRecord::Migration
  def self.up
    create_table :discounts do |t|      
      t.references :checkout
      t.references :coupon
      t.decimal :amount, :precision => 8, :scale => 2, :default => 0.0, :null => false
      t.timestamps
    end
  end

  def self.down
    drop_table :discounts
  end
end
