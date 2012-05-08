# Redefine Product model to just what is needed in order to solve problems with
# rake test_app in Postgres
class Product < ActiveRecord::Base
  has_many :variants

  def has_variants?
    !variants.empty?
  end
end

class AddCountOnHandToVariantsAndProducts < ActiveRecord::Migration
  def up
    add_column :variants, :count_on_hand, :integer, :default => 0, :null => false
    add_column :products, :count_on_hand, :integer, :default => 0, :null => false

    # Due to our namespacing changes, this migration (from earlier Spree versions) is broken
    # To fix it, temporarily set table name on each of the models involved
    # And then...
    Spree::Variant.table_name = 'variants'
    Spree::Product.table_name = 'products'
    Spree::InventoryUnit.table_name = 'inventory_units'

    # In some cases needed to reflect changes in table structure
    Spree::Variant.reset_column_information
    Spree::Product.reset_column_information

    say_with_time 'Transfering inventory units with status on_hand to variants table...' do
      Spree::Variant.all.each do |v|
        v.update_attribute(:count_on_hand, v.inventory_units.with_state('on_hand').size)
        Spree::InventoryUnit.destroy_all(:variant_id => v.id, :state => 'on_hand')
      end
    end

    say_with_time 'Updating products count on hand' do
      Spree::Product.all.each do |p|
        product_count_on_hand = p.has_variants? ?
            p.variants.inject(0) { |acc, v| acc + v.count_on_hand } :
            (p.master ? p.master.count_on_hand : 0)
        p.update_attribute(:count_on_hand, product_count_on_hand)
      end
    end

    # ... Switch things back at the end of the migration
    Spree::Variant.table_name = 'spree_variants'
    Spree::Product.table_name = 'spree_products'
    Spree::InventoryUnit.table_name = 'spree_inventory_units'
  end

  def down
   Spree::Variant.all.each do |v|
      v.count_on_hand.times do
        Spree::InventoryUnit.create(:variant => variant, :state => 'on_hand')
      end
    end

    remove_column :variants, :count_on_hand
    remove_column :products, :count_on_hand
  end
end
