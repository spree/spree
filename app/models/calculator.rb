class Calculator < ActiveRecord::Base  
  belongs_to :calculable, :polymorphic => true     
  validates_presence_of :calculable_id
    
  def self.shipping
    all.select { |c| c.is_a? ShippingCalculator }
  end
  
  def available?(order)
    true
  end 

  def to_s
    self.class.to_s.titleize
  end      
  
end
