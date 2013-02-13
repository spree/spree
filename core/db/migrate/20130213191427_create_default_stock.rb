class CreateDefaultStock < ActiveRecord::Migration
  def up
    location = Spree::StockLocation.create(name: 'default')
    Spree::Variant.all.each do |variant|
      location.stock_items.create(variant: variant, count_on_hand: variant.count_on_hand)
    end

    remove_column :spree_variants, :count_on_hand
  end

  def down
    add_column :spree_variants, :count_on_hand, :integer

    Spree::StockItem.all.each do |stock_item|
      stock_item.variant.update_column :count_on_hand, stock_item.count_on_hand
    end

    Spree::StockLocation.delete_all
    Spree::StockItem.delete_all
  end
end
