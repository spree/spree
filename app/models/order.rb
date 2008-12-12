class Order < ActiveRecord::Base  
  before_create :generate_order_number
  before_save :update_line_items
  
  has_many :line_items, :dependent => :destroy, :attributes => true do
    def in_order(variant)
      find :first, :conditions => ['variant_id = ?', variant.id]
    end
  end
  has_many :products, :through => :line_items
  has_many :inventory_units
  has_many :state_events
  has_one :creditcard_payment
  belongs_to :user
  has_one :address, :as => :addressable, :dependent => :destroy

  validates_associated :line_items, :message => "are not valid"
  validates_numericality_of :tax_amount
  validates_numericality_of :ship_amount
  validates_numericality_of :item_total
  validates_numericality_of :total

  named_scope :by_number, lambda {|number| {:conditions => ["number = ?", number]}}
  named_scope :between, lambda {|*dates| {:conditions => ["orders.created_at between :start and :stop", {:start => dates.first.to_date, :stop => dates.last.to_date}]}}
  named_scope :by_customer, lambda {|customer| {:include => :user, :conditions => ["users.email = ?", customer]}}
  named_scope :by_state, lambda {|state| {:conditions => ["state = ?", state]}}
  named_scope :checkout_completed, lambda {|state| {:conditions => ["checkout_complete = ?", state]}}
  
  
  # attr_accessible is a nightmare with attachment_fu, so use attr_protected instead.
  attr_protected :ship_amount, :tax_amount, :item_total, :total, :user, :number, :ip_address, :checkout_complete, :state
  
  # order state machine (see http://github.com/pluginaweek/state_machine/tree/master for details)
  state_machine :initial => 'in_progress' do    
    after_transition :to => 'in_progress', :do => lambda {|order| order.update_attribute(:checkout_complete, false)}
    after_transition :to => 'authorized', :do => :complete_order
    after_transition :to => 'shipped', :do => :mark_shipped
    after_transition :to => 'canceled', :do => :cancel_order
    after_transition :to => 'returned', :do => :restock_inventory
    
    event :next do
      transition :to => 'address', :from => 'in_progress'
      transition :to => 'creditcard_payment', :from => 'address'
      transition :to => 'authorized', :from => 'creditcard_payment'
    end
    event :previous do
      transition :to => 'address', :from => 'creditcard_payment'
      transition :to => 'in_progress', :from => 'address'
    end
    event :edit do
      transition :to => 'in_progress', :from => %w{address creditcard_payment in_progress}
    end
    event :capture do
      transition :to => 'captured', :from => 'authorized'
    end
    event :ship do
      transition :to => 'shipped', :from => 'captured'
      # todo: also allow from authorized state (but we need to make sure capture is applied first)
    end
    event :cancel do
      transition :to => 'canceled', :if => :allow_cancel?
    end
    event :return do
      transition :to => 'returned', :from => 'shipped'
    end
  end

  def allow_cancel?
    self.checkout_complete && self.state != 'canceled'
  end
  
  def add_variant(variant, quantity=1)
    current_item = line_items.in_order(variant)
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
      random = Array.new(9){rand(9)}.join
      record = Order.find(:first, :conditions => ["number = ?", random])
    end
    self.number = random
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
 
  private
  def complete_order
    self.update_attribute(:checkout_complete, true)
    InventoryUnit.sell_units(self)
    if user && user.email
      OrderMailer.deliver_confirm(self)
    end
  end
  
  def cancel_order
    restock_inventory
    OrderMailer.deliver_cancel(self)
  end
  
  def mark_shipped
    inventory_units.each do |inventory_unit|
      inventory_unit.ship!
    end
  end
  
  def restock_inventory
    inventory_units.each do |inventory_unit|
      inventory_unit.restock!
    end
  end
  
  def update_line_items
    self.line_items.each do |line_item|
      LineItem.destroy(line_item.id) if line_item.quantity == 0
    end
  end  

end
