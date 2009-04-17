class Order < ActiveRecord::Base  
#  before_create :generate_order_number
  before_save :update_line_items 
  before_create :generate_token
  
  has_many :line_items, :dependent => :destroy, :attributes => true
  has_many :inventory_units
  has_many :state_events
  has_many :payments
  has_many :creditcard_payments
  has_many :creditcards
  belongs_to :user
  has_many :shipments, :dependent => :destroy
  belongs_to :bill_address, :foreign_key => "bill_address_id", :class_name => "Address"
  belongs_to :ship_address, :foreign_key => "ship_address_id", :class_name => "Address"
  accepts_nested_attributes_for :creditcards, :reject_if => proc { |attributes| attributes['number'].blank? }  
  accepts_nested_attributes_for :ship_address, :bill_address
  
  validates_associated :line_items, :message => "are not valid"
  validates_numericality_of :tax_amount
  validates_numericality_of :ship_amount
  validates_numericality_of :item_total
  validates_numericality_of :total

  named_scope :by_number, lambda {|number| {:conditions => ["orders.number = ?", number]}}
  named_scope :between, lambda {|*dates| {:conditions => ["orders.created_at between :start and :stop", {:start => dates.first.to_date, :stop => dates.last.to_date}]}}
  named_scope :by_customer, lambda {|customer| {:include => :user, :conditions => ["users.email = ?", customer]}}
  named_scope :by_state, lambda {|state| {:conditions => ["state = ?", state]}}
  named_scope :checkout_completed, lambda {|state| {:conditions => ["checkout_complete = ?", state]}}
  
  
  # attr_accessible is a nightmare with attachment_fu, so use attr_protected instead.
  attr_protected :ship_amount, :tax_amount, :item_total, :total, :user, :number, :ip_address, :checkout_complete, :state, :token
  
  def to_param  
    self.number if self.number
    generate_order_number unless self.number
    self.number.parameterize.to_s.upcase
  end
  make_permalink :field => :number
  
  # order state machine (see http://github.com/pluginaweek/state_machine/tree/master for details)
  state_machine :initial => 'in_progress' do    
    after_transition :to => 'in_progress', :do => lambda {|order| order.update_attribute(:checkout_complete, false)}
    after_transition :to => 'new', :do => :complete_order
    after_transition :to => 'canceled', :do => :cancel_order
    after_transition :to => 'returned', :do => :restock_inventory
    after_transition :to => 'resumed', :do => :restore_state 
     
    event :complete do
      transition :to => 'new', :from => 'in_progress'
    end
    event :cancel do
      transition :to => 'canceled', :if => :allow_cancel?
    end
    event :return do
      transition :to => 'returned', :from => 'shipped'
    end
    event :resume do 
      transition :to => 'resumed', :from => 'canceled', :if => :allow_resume?
    end    
    event :pay do
      transition :to => 'paid', :if => :allow_pay?
    end
    event :ship do
      transition :to => 'shipped', :from  => 'paid'
    end
  end
  
  def restore_state
    # pop the resume event so we can see what the event before that was
    state_events.pop if state_events.last.name == "resume"
    update_attribute("state", state_events.last.previous_state)
  end

  def allow_cancel?
    self.state != 'canceled'
  end
  
  def allow_resume?
    # we shouldn't allow resume for legacy orders b/c we lack the information necessary to restore to a previous state
    return false if state_events.empty? || state_events.last.previous_state.nil?
    true
  end
  
  def allow_pay?
    checkout_complete
  end
  
  def add_variant(variant, quantity=1)
    current_item = contains?(variant)
    if current_item
      current_item.increment_quantity unless quantity > 1
      current_item.quantity = (current_item.quantity + quantity) if quantity > 1
      current_item.save
    else
      current_item = LineItem.new(:quantity => quantity, :variant => variant, :price => variant.price)
      self.line_items << current_item
    end
    
    # populate line_items attributes for additional_fields entries
    # that have populate => [:line_item]
    Variant.additional_fields.select{|f| !f[:populate].nil? && f[:populate].include?(:line_item) }.each do |field| 
      value = ""
      
      if field[:only].nil? || field[:only].include?(:variant)
        value = variant.send(field[:name].gsub(" ", "_").downcase)
      elsif field[:only].include?(:product)
        value = variant.product.send(field[:name].gsub(" ", "_").downcase)
      end
      current_item.update_attribute(field[:name].gsub(" ", "_").downcase, value)
    end
  end

  def generate_order_number                
    record = true
    while record
      random = "R#{Array.new(9){rand(9)}.join}"                                        
      record = Order.find(:first, :conditions => ["number = ?", random])
    end          
    self.number = random
  end          
  
  def payment_total
    payments.inject(0) {|sum, payment| sum + payment.amount}
  end

  # total of line items (no tax or shipping inc.)
  def item_total
    tot = 0
    self.line_items.each do |li|
      tot += li.total
    end
    self.item_total = tot
  end
  
  def total
    self.total = self.item_total + self.ship_amount + self.tax_amount
  end 
 
  # convenience method since many stores will not allow user to create multiple shipments
  def shipment
    shipments.last
  end
  
  def contains?(variant)
    line_items.select { |line_item| line_item.variant == variant }.first
  end

  def grant_access?(token=nil)
    return true if token && token == self.token
    return false unless current_user_session = UserSession.find   
    return current_user_session.user == self.user
  end
  def mark_shipped
    inventory_units.each do |inventory_unit|
      inventory_unit.ship!
    end
  end
      
  # collection of available shipping countries
  def shipping_countries
    ShippingMethod.all.collect { |method| method.zone.country_list }.flatten.uniq.sort_by {|item| item.send 'name'}
  end
  
  def shipping_methods
    return [] unless ship_address
    ShippingMethod.all.select { |method| method.zone.include?(ship_address) && method.available?(self) }
  end
   
  def update_totals
    # finalize order totals 
    unless shipment.nil?
      calculator = shipment.shipping_method.shipping_calculator.constantize.new
      self.ship_amount = calculator.calculate_shipping(shipment) 
    else
      self.ship_amount = 0
    end
    self.tax_amount = calculate_tax
  end  

  private
  def complete_order
    self.update_attribute(:checkout_complete, true)
    InventoryUnit.sell_units(self)
    if user && user.email
      OrderMailer.deliver_confirm(self)
    end   
    update_totals
    save
  end   
  
  def cancel_order
    restock_inventory
    OrderMailer.deliver_cancel(self)
  end
  
  def restock_inventory
    inventory_units.each do |inventory_unit|
      inventory_unit.restock! if inventory_unit.can_restock?
    end
  end
  
  def update_line_items
    self.line_items.each do |line_item|
      LineItem.destroy(line_item.id) if line_item.quantity == 0
    end
  end
  
  def generate_token
    self.token = Authlogic::Random.friendly_token    
  end      
end
