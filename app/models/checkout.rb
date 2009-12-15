class Checkout < ActiveRecord::Base
  extend ValidationGroup::ActiveRecord::ActsMethods

  after_save :process_coupon_code
  before_validation :clone_billing_address, :if => "@use_billing"

  belongs_to :order
  belongs_to :bill_address, :foreign_key => "bill_address_id", :class_name => "Address"
  has_one :shipment, :through => :order, :source => :shipments, :order => "shipments.created_at ASC"
  has_one :creditcard

  accepts_nested_attributes_for :bill_address
  accepts_nested_attributes_for :shipment
  accepts_nested_attributes_for :creditcard

  attr_accessor :coupon_code
  attr_accessor :use_billing

  validates_presence_of :order_id
  validates_format_of :email, :with => /^\S+@\S+\.\S+$/, :allow_blank => true

  validation_group :register, :fields => ["email"]

  validation_group :address, :fields=>["bill_address.firstname", "bill_address.lastname", "bill_address.phone",
                                       "bill_address.zipcode", "bill_address.state", "bill_address.lastname",
                                       "bill_address.address1", "bill_address.city", "bill_address.statename",
                                       "bill_address.zipcode", "shipment.address.firstname", "shipment.address.lastname", "shipment.address.phone",
                                       "shipment.address.zipcode", "shipment.address.state", "shipment.address.lastname",
                                       "shipment.address.address1", "shipment.address.city", "shipment.address.statename",
                                       "shipment.address.zipcode"]
  validation_group :delivery, :fields => []

  def completed_at
    order.completed_at
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

  private
  def clone_billing_address
    shipment.address = bill_address.clone
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

end
