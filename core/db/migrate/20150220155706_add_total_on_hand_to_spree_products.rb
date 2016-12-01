class AddTotalOnHandToSpreeProducts < ActiveRecord::Migration
  def change
    add_column :spree_products, :count_on_hand, :integer, null: false, default: 0
    # seed the counts
    Spree::Variant.all.each { |v| v.update_counter_cache }
    Spree::Product.all.each { |v| v.update_counter_cache }
  end


end
