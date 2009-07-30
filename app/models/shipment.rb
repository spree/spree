class Shipment < ActiveRecord::Base        
  belongs_to :order
  belongs_to :shipping_method
  belongs_to :address
  has_one    :charge,   :as => :adjustment_source

  before_create :generate_shipment_number
  after_save :transition_order
  after_save :create_shipping_charge
  
  attr_accessor :special_instructions 
  accepts_nested_attributes_for :address
     
  def shipped?
    self.shipped_at
  end
  
  def shipped=(value)
    return unless value == "1" && shipped_at.nil?
    self.shipped_at = Time.now
  end

  def create_shipping_charge
    if shipping_method
      self.charge ||= Charge.create({
          :order => order,
          :secondary_type => "ShippingCharge",
          :description => "#{I18n.t(:shipping)} (#{shipping_method.name})",
          :adjustment_source => self,
        })
    end
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
    # transition order to shipped if all shipments have been shipped
    return unless shipped_at_changed?
    order.shipments.each do |shipment|
      return unless shipment.shipped?
    end
    current_user_session = UserSession.find   
    current_user = current_user_session.user if current_user_session    
    order.ship!                                        
    order.state_events.create(:name => I18n.t('ship'), :user => current_user, :previous_state => order.state_was)
  end
end
