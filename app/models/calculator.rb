class Calculator < ActiveRecord::Base  
  belongs_to :calculable, :polymorphic => true     
    
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
