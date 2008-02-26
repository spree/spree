class CreateOrders < ActiveRecord::Migration
  def self.up
	  create_table "orders", :force => true do |t|
      t.column "user_id",              :integer
      t.column "number",               :string, :limit => 15
      t.column "status",               :integer
      t.column "ship_method",          :integer
      t.column "ship_amount",          :decimal,                :precision => 8, :scale => 2, :default => 0.0, :null => false
      t.column "tax_amount",           :decimal,                :precision => 8, :scale => 2, :default => 0.0, :null => false
      t.column "item_total",           :decimal,                :precision => 8, :scale => 2, :default => 0.0, :null => false
      t.column "total",                :decimal,                :precision => 8, :scale => 2, :default => 0.0, :null => false
      t.column "ip_address",           :string, :limit => 11
      t.column "special_instructions", :text
      t.column "ship_address_id",      :integer
      t.column "bill_address_id",      :integer
      t.column "created_at",           :datetime
      t.column "updated_at",           :datetime
    end
  end

  def self.down
    drop_table "orders"
  end
end