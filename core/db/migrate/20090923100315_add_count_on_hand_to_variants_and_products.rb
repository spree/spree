class AddCountOnHandToVariantsAndProducts < ActiveRecord::Migration
  def self.up
    add_column :variants, :count_on_hand, :integer, :default => 0, :null => false
    add_column :products, :count_on_hand, :integer, :default => 0, :null => false

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
  end

  def self.down
   Spree::Variant.all.each do |v|
      v.count_on_hand.times do
        Spree::InventoryUnit.create(:variant => variant, :state => 'on_hand')
      end
    end

    remove_column :variants, :count_on_hand
    remove_column :products, :count_on_hand
  end
end
