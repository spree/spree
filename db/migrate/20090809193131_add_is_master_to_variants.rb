class AddIsMasterToVariants < ActiveRecord::Migration
  def self.up
    change_table :variants do |t|
      t.boolean "is_master", :default => false
    end
    
    Variant.class_eval do
      # temporarily disable validation so we can pull off the migration
      def check_price
      end
    end
    
    ## Flag the first variant of each product as the "master" variant 
    variants = Variant.all
    unless variants.empty? 
      # select first variant of each product as "master" and flag it in the database
      sorted_variants = variants.sort{|a,b| a.product_id <=> b.product_id}.sort{|a,b| a.id <=> b.id}
      master_variants = sorted_variants.inject([]) {|m, v| m << v unless m.detect{|d| d.product_id == v.product_id}; m}
      master_variants.each{|v| v.update_attributes(:is_master => true, :price => v.product.attributes["master_price"])}
    end
  end

  def self.down
    change_table :variants do |t|
      t.remove "is_master"
    end
  end
end



