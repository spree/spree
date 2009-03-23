class Shipment < ActiveRecord::Base      
  include ActionView::Helpers::NumberHelper # Needed for JS usable rate information
  
  belongs_to :order
  belongs_to :shipping_method
  has_one :address, :as => :addressable, :dependent => :destroy

  before_create :generate_shipment_number
  after_save :recalculate_tax
  after_save :transition_order
    
  def shipped?
    self.shipped_at
  end
    
  def shipping_methods
    ShippingMethod.all.select { |method| method.zone.include?(address) && method.available?(order) }
  end 
  
  def rates
    quotes = []
    shipping_methods.each do |method|
      quotes << {:id => method.id, :name => method.name, :rate => number_to_currency(method.calculate_shipping(self)) }
    end
    quotes
  end

  private  
  def generate_shipment_number
    record = true
    while record
      random = Array.new(11){rand(9)}.join
      record = Shipment.find(:first, :conditions => ["number = ?", random])
    end
    self.number = random
  end
  
  def transition_order
    return unless shipped_at_changed?
    order.shipments.each do |shipment|
      return unless shipment.shipped?
    end
    # transition order to shipped if all shipments have been shipped
    order.ship!
  end
  
  def recalculate_tax
    return unless order && order.respond_to?(:calculate_tax)      
    order.update_attribute("tax_amount", order.calculate_tax)
  end
end