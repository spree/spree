class Order < ActiveRecord::Base  
  before_save :update_user_addresses
  
  has_many :line_items
  has_many :inventory_units
  has_many :order_operations
  has_one :credit_card
  belongs_to :user
  belongs_to :bill_address, :class_name => "Address", :foreign_key => :bill_address_id
  belongs_to :ship_address, :class_name => "Address", :foreign_key => :ship_address_id

  enumerable_constant :status, :constants => ORDER_STATES
  enumerable_constant :ship_method, {:constants => SHIPPING_METHODS, :no_validation => true}

  #TODO - validate presence of user once we have the means to add one through controller
  validates_presence_of :line_items
  validates_associated :line_items, :message => "are not valid"
  validates_numericality_of :tax_amount
  validates_numericality_of :ship_amount
  validates_numericality_of :item_total
  validates_numericality_of :total

  def self.new_from_cart(cart)
    return nil if cart.cart_items.empty?
    order = self.new
    order.line_items = cart.cart_items.map do |item|
      LineItem.from_cart_item(item)
    end
    order
  end

  def self.generate_order_number
    record = true
    while record
      random = Array.new(9){rand(9)}.join
      record = find(:first, :conditions => ["number = ?", random])
    end
    return random
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


  # Generate standard options used by ActiveMerchant gateway for authorize, capture, etc. 
  def self.gateway_options(order)
    billing_address = {:name => order.bill_address.full_name,
                       :address1 => order.bill_address.address1,
                       :address2 => order.bill_address.address2, 
                       :city => order.bill_address.city,
                       :state => order.bill_address.state.abbr, 
                       :zip => order.bill_address.zipcode,
                       :country => order.bill_address.country.name,
                       :phone => order.bill_address.phone}
    shipping_address = {:name => order.ship_address.full_name,
                       :address1 => order.ship_address.address1,
                       :address2 => order.ship_address.address2, 
                       :city => order.ship_address.city,
                       :state => order.ship_address.state.abbr, 
                       :zip => order.ship_address.zipcode,
                       :country => order.ship_address.country.name,
                       :phone => order.ship_address.phone}
    options = {:billing_address => billing_address, :shipping_address => shipping_address}
    options.merge(self.minimal_gateway_options(order))
  end
 
  # Generates a minimal set of gateway options.  There appears to be some issues with passing in 
  # a billing address when authorizing/voiding a previously captured transaction.  So omits these 
  # options in this case since they aren't necessary.  
  def self.minimal_gateway_options(order)
    {:email => order.user.email, 
     :customer => order.user.login, 
     :ip => order.ip_address, 
     :order_id => order.number,
     :shipping => order.ship_amount * 100,
     :tax => order.tax_amount * 100, 
     :subtotal => order.item_total * 100}  
  end

  protected
  
    def update_user_addresses
      return unless bill_address
      new_addys = [ship_address]
      new_addys << bill_address unless ship_address == bill_address
      new_addys.each do |address|
        self.user.addresses << address unless user.addresses.include?(address)         
      end
      self.user.save!
    end
end
