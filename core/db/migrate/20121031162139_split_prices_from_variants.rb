class SplitPricesFromVariants < ActiveRecord::Migration
  def up
    create_table :spree_prices do |t|
      t.integer :variant_id, :null => false
      t.decimal :amount, :precision => 8, :scale => 2, :null => false
      t.string :currency
    end

    Spree::Variant.all.each do |variant|
      Spree::Price.create!(
        :variant_id => variant.id,
        :amount => variant[:price],
        :currency => Spree::Config[:currency]
      )
    end

    remove_column :spree_variants, :price
  end

  def down
    prices = ActiveRecord::Base.connection.execute("select variant_id, amount from spree_prices")
    add_column :spree_variants, :price, :decimal, :after => :sku, :scale => 2, :precision => 8

    prices.each do |price|
      ActiveRecord::Base.connection.execute("update spree_variants set price = #{price['amount']} where id = #{price['variant_id']}")
    end
    
    change_column :spree_variants, :price, :decimal, :after => :sku, :scale => 2, :precision => 8, :null => false
    drop_table :spree_prices
  end
end
