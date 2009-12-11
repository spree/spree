class Checkout < ActiveRecord::Base
  extend ValidationGroup::ActiveRecord::ActsMethods

  before_save :check_addresses_on_duplication
  after_save :process_coupon_code
  after_save :update_order_shipment
  before_validation :clone_billing_address, :if => "@use_billing"

  belongs_to :order
  belongs_to :bill_address, :foreign_key => "bill_address_id", :class_name => "Address"
  belongs_to :ship_address, :foreign_key => "ship_address_id", :class_name => "Address"
  belongs_to :shipping_method

  has_one :creditcard
  
  accepts_nested_attributes_for :bill_address
  accepts_nested_attributes_for :ship_address
  accepts_nested_attributes_for :creditcard

  attr_accessor :coupon_code
  attr_accessor :use_billing

  validates_presence_of :order_id
  validates_format_of :email, :with => /^\S+@\S+\.\S+$/, :allow_blank => true

  validation_group :register, :fields => ["email"]

  validation_group :address, :fields=>["bill_address.firstname", "bill_address.lastname", "bill_address.phone",
                                       "bill_address.zipcode", "bill_address.state", "bill_address.lastname",
                                       "bill_address.address1", "bill_address.city", "bill_address.statename",
                                       "bill_address.zipcode", "ship_address.firstname", "ship_address.lastname", "ship_address.phone",
                                       "ship_address.zipcode", "ship_address.state", "ship_address.lastname",
                                       "ship_address.address1", "ship_address.city", "ship_address.statename",
                                       "ship_address.zipcode"]
  validation_group :delivery, :fields => []

  def completed_at
    order.completed_at
  end

  # This is a temporary Shipment object for the purpose of showing available shiping rates in delivery step of checkout
  def shipment
    @shipment ||= Shipment.new(:order => order, :address => ship_address)
  end


  alias :ar_valid? :valid?
  def valid?
    # will perform partial validation when @checkout.enabled_validation_group :step is called
    result = ar_valid?
    return result unless validation_group_enabled?

    relevant_errors = errors.select { |attr, msg| @current_validation_fields.include?(attr) }
    errors.clear
    relevant_errors.each { |attr, msg| errors.add(attr, msg) }
    relevant_errors.empty?
  end

  # checkout state machine (see http://github.com/pluginaweek/state_machine/tree/master for details)
  state_machine :initial => 'address' do
    after_transition :to => 'complete', :do => :complete_order
    before_transition :to => 'complete', :do => :process_payment
    event :next do
      transition :to => 'delivery', :from  => 'address'
      transition :to => 'payment', :from => 'delivery'
      transition :to => 'complete', :from => 'payment'
    end
  end
  def self.state_names
    state_machine.states.by_priority.map(&:name)
  end

  def shipping_methods
    return [] unless ship_address
    ShippingMethod.all_available_to_address(ship_address)
  end

  private

  def check_addresses_on_duplication
    if order.user      
      if ship_address and order.user.ship_address.nil?
        order.user.update_attribute(:ship_address, ship_address)
      elsif order.user.ship_address and ship_address.nil?
        self.ship_address = order.user.ship_address
      end
        
      if bill_address and order.user.bill_address.nil?
        order.user.update_attribute(:bill_address, bill_address)
      elsif order.user.bill_address and bill_address.nil?
        self.bill_address = order.user.ship_address
      end
    end
  end
  
  def clone_billing_address
    self.ship_address = bill_address.clone
    true
  end
  
  def complete_order
    order.complete!
    order.pay! if Spree::Config[:auto_capture]
  end

  def process_payment
    begin
      if Spree::Config[:auto_capture]
        creditcard.purchase(order.total)
      else
        creditcard.authorize(order.total)
      end
    end
  end

  def process_coupon_code
    return unless @coupon_code and coupon = Coupon.find_by_code(@coupon_code.upcase)
    coupon.create_discount(order)
    # recalculate order totals
    order.save
  end

  # list of countries available for checkout
  def self.countries   
    return Country.all unless zone = Zone.find_by_name(Spree::Config[:checkout_zone])
    zone.country_list
  end

  def update_order_shipment
    if order.shipment
      order.shipment.shipping_method = shipping_method
      order.shipment.address = ship_address
      order.shipment.save
    end
  end
  
end
