class CreateDefaultStock < ActiveRecord::Migration
  def up
    unless column_exists? :spree_stock_locations, :default
      add_column :spree_stock_locations, :default, :boolean, null: false, default: false
    end

    Spree::StockLocation.skip_callback(:create, :after, :create_stock_items)
    Spree::StockLocation.skip_callback(:save, :after, :ensure_one_default)
    Spree::StockItem.skip_callback(:save, :after, :process_backorders)
    location = Spree::StockLocation.new(name: 'default')
    location.save(validate: false)

    Spree::Variant.find_each do |variant|
      stock_item = Spree::StockItem.unscoped.build(stock_location: location, variant: variant)
      stock_item.send(:count_on_hand=, variant.count_on_hand)
      # Avoid running default_scope defined by acts_as_paranoid, related to #3805,
      # validations would run a query with a delete_at column that might not be present yet
      stock_item.save! validate: false
    end

    remove_column :spree_variants, :count_on_hand
  end

  def down
    add_column :spree_variants, :count_on_hand, :integer

    Spree::StockItem.find_each do |stock_item|
      stock_item.variant.update_column :count_on_hand, stock_item.count_on_hand
    end

    Spree::StockLocation.delete_all
    Spree::StockItem.delete_all
  end
end
