class CreateDefaultStock < ActiveRecord::Migration
  def up
    Spree::StockLocation.skip_callback(:create, :after, :create_stock_items)
    Spree::StockItem.skip_callback(:save, :after, :process_backorders)
    location = Spree::StockLocation.new(name: 'default')
    location.save(validate: false)

    Spree::StockItem.class_eval do
      # Column name check here for #3805
      unless column_names.include?("deleted_at")
        def self.acts_as_paranoid; end
      end
    end

    Spree::Variant.all.each do |variant|
      stock_item = location.stock_items.build(variant: variant)
      stock_item.send(:count_on_hand=, variant.count_on_hand)
      stock_item.save!
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

