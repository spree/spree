class Shipment < ActiveRecord::Base
  before_create :generate_shipment_number
  belongs_to :order
  belongs_to :shipping_method

  after_save :transition_order
  has_one :address, :as => :addressable, :dependent => :destroy
    
  def shipped?
    self.shipped_at
  end
    
  def shipping_methods
    ShippingMethod.all.select { |method| method.zone.include?(address) }
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
end