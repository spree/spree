class Variant < ActiveRecord::Base
  belongs_to :product
  has_many :inventory_units
  has_and_belongs_to_many :option_values
  validates_presence_of :product
  
  # gives the inventory count for variants with the specified inventory status 
  def inventory(status)
    InventoryUnit.count(:conditions => "status = #{status} AND variant_id = #{self.id}", :joins => "LEFT JOIN variants on variants.id = variant_id")
  end
end
