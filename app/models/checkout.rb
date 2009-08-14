class Checkout < ActiveRecord::Base  
  before_save :authorize_creditcard, :unless => "Spree::Config[:auto_capture]"
  before_save :capture_creditcard, :if => "Spree::Config[:auto_capture]"
  after_save :process_coupon_code
  
  belongs_to :order
  belongs_to :bill_address, :foreign_key => "bill_address_id", :class_name => "Address"
  has_one :shipment, :through => :order, :source => :shipments, :order => "shipments.created_at ASC"                       
  
  accepts_nested_attributes_for :bill_address
  accepts_nested_attributes_for :shipment

  # for memory-only storage of creditcard details
  attr_accessor :creditcard    
  attr_accessor :coupon_code

  validates_presence_of :order_id

  private
  def authorize_creditcard
    return unless process_creditcard? 
    cc = Creditcard.new(creditcard.merge(:address => self.bill_address, :checkout => self))
    return unless cc.valid? and cc.authorize(order.total)
    order.complete
  end

  def capture_creditcard
    return unless process_creditcard? 
    cc = Creditcard.new(creditcard.merge(:address => self.bill_address, :checkout => self))
    return unless cc.valid? and cc.purchase(order.total)
    order.complete
    order.pay
  end

  def process_creditcard?
    order and creditcard and not creditcard[:number].blank?
  end

  def process_coupon_code
    return unless @coupon_code and coupon = Coupon.find_by_code(@coupon_code.upcase)
    coupon.create_discount(order)       
    # recalculate order totals
    order.save
  end

end
