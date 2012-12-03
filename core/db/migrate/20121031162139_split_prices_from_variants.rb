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
        :amount => variant.price,
        :currency => Spree::Config[:currency]
      )
    end

    remove_column :spree_variants, :price
  end

  def down
    add_column :spree_variants, :price, :decimal, :after => :sku, :scale => 8, :precision => 2

    Spree::Variant.all.each do |variant|
      variant.price = variant.default_price.amount
      variant.save!
    end

    drop_table :spree_prices
  end
end
