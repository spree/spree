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
    
    # Convert the old variant structure to the new one
    Product.all(:include => {:variants => :option_values}).each do |p|
      price = p.attributes["master_price"]
    
      master_variant = p.variants.detect{|v| v.option_values.empty?} 

      # check for price anomalies
      if master_variant && master_variant.price != price 
          warn "[migration] single variant price doesn't match product master price #{price} for v = #{master_variant.inspect}"
      end

      master_variant ||= Variant.new(:product => p)
      master_variant.update_attributes(:price => price, :is_master => true)
      p.save                          # to trigger the consistency filters
    end
  end

  def self.down
    Product.all(:include => :variants).each do |p| 
      unless p.variants.empty?
        p.master.delete
      end
    end
    change_table :variants do |t|
      t.remove "is_master"
    end
  end
end



