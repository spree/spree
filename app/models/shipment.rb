class Shipment < ActiveRecord::Base        
  belongs_to :order
  belongs_to :shipping_method
  belongs_to :address

  before_create :generate_shipment_number
  after_save :recalculate_tax
  after_save :transition_order

  accepts_nested_attributes_for :address 
     
  def shipped?
    self.shipped_at
  end
  
  def shipped=(value)
    return unless value == "1" && shipped_at.nil?
    self.shipped_at = Time.now
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
  
  def recalculate_tax
    return unless order && order.respond_to?(:calculate_tax)      
    order.update_attribute("tax_amount", order.calculate_tax)
  end
end