class Order < ActiveRecord::Base  
  before_create :generate_order_number
  before_save :update_line_items #, :update_user_addresses
  
  has_many :line_items, :dependent => :destroy, :attributes => true do
    def in_order(variant)
      find :first, :conditions => ['variant_id = ?', variant.id]
    end
  end
  has_many :products, :through => :line_items
  has_many :inventory_units
  has_many :order_operations
  has_one :creditcard_payment
  belongs_to :user
  has_one :address, :as => :addressable
  belongs_to :bill_address, :class_name => "Address", :foreign_key => :bill_address_id
  belongs_to :ship_address, :class_name => "Address", :foreign_key => :ship_address_id

  enumerable_constant :status, :constants => [:incomplete, :authorized, :captured, :canceled, :returned, :shipped, :paid, :pending_payment, :abandoned]
  enumerable_constant :ship_method, {:constants => SHIPPING_METHODS, :no_validation => true}

  #TODO - validate presence of user once we have the means to add one through controller
  #validates_presence_of :line_items
  validates_associated :line_items, :message => "are not valid"
  validates_numericality_of :tax_amount
  validates_numericality_of :ship_amount
  validates_numericality_of :item_total
  validates_numericality_of :total

  # order state machine (see http://github.com/pluginaweek/state_machine/tree/master for details)
  state_machine :checkout_state, :initial => 'edit' do    
    #after_enter :confirm, :finalize!    
    event :next do
      transition :to => 'address', :from => 'edit'
      transition :to => 'creditcard_payment', :from => 'address'
      transition :to => 'confirm', :from => 'creditcard_payment'
    end
    event :previous do
      transition :to => 'address', :from => 'creditcard_payment'
      transition :to => 'edit', :from => 'address'
    end
    event :edit do
      transition :to => 'edit'
    end
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
  
  def self.current_order
    unless session[:order_id].blank?
      @order = Order.find_or_create_by_id(session[:order_id])
    else      
      @order = Order.new
    end
  end
  
  def cancel
    self.status = Order::Status::CANCELED      
    creditcard_payment.void
    save
  end
  
  def ship
    creditcard_payment.capture if status == Order::Status::AUTHORIZED          
    self.status = Order::Status::SHIPPED
    inventory_units.each { |unit| unit.update_attributes(:status => InventoryUnit::Status::SHIPPED) }
    save
  end
  
  def return
    Order.transaction do
      self.status = Order::Status::RETURNED    
      inventory_units.each do |unit|     
        unit.update_attributes(:status => InventoryUnit::Status::ON_HAND)
      end
      save
    end
  end
 
  private
=begin  
  def update_user_addresses 
    return unless bill_address
    new_addys = [bill_address]
    new_addys << ship_address unless ship_address == bill_address
    new_addys.each do |addy|
      user.add_address addy unless user.addresses.include?(addy)         
    end
    user.save!
  end
=end  
  def update_line_items
    self.line_items.each do |line_item|
      LineItem.destroy(line_item.id) if line_item.quantity == 0
    end
  end
  
  def finalize!
    #TODO 
  end

end
