class CreateShippingRates < ActiveRecord::Migration
  def self.up
    create_table :shipping_rates do |t|
      t.column :shipping_category_id, :integer
      t.column :shipping_method_id, :integer
    end
  end

  def self.down
    drop_table :shipping_rates
  end
end
