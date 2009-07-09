class Checkout < ActiveRecord::Base  
  before_save :authorize_creditcard, :unless => "Spree::Config[:auto_capture]"
  before_save :capture_creditcard, :if => "Spree::Config[:auto_capture]"
  after_save :update_charges
  after_save :update_credits
  after_save :process_coupon_code

  belongs_to :order
  belongs_to :shipping_method
  belongs_to :bill_address, :foreign_key => "bill_address_id", :class_name => "Address"
  belongs_to :ship_address, :foreign_key => "ship_address_id", :class_name => "Address"
  has_many :discounts, :dependent => :destroy

  accepts_nested_attributes_for :ship_address, :bill_address

  # for memory-only storage of creditcard details
  attr_accessor :creditcard    
  attr_accessor :coupon_code

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
  def update_charges
    # update shipping (if applicable)
    if shipping_method
      ship_charge = order.shipping_charges.first
      ship_charge ||= order.shipping_charges.build    
      ship_charge.amount = shipping_method.calculate_shipping(Shipment.new(:order => order, :address => ship_address))
      ship_charge.description = "#{I18n.t(:shipping)} (#{shipping_method.name})" 
      ship_charge.save
    end
    # update tax (if applicable)
    tax_amount = order.calculate_tax
    if tax_amount > 0                           
      tax_charge = order.tax_charges.first
      tax_charge ||= order.tax_charges.build(:description => I18n.t(:tax))
      tax_charge.amount = tax_amount
      tax_charge.save    
    end

    order.reload
    order.update_totals
    order.save 
  end 
  
  def update_credits                
    order.credits.each do |credit|
      # provide opportunity for coupon related discounts to be recalculated 
      creditable = credit.creditable
      creditable.update_credit if creditable.is_a?(Discount)
    end
  end

  def process_coupon_code    
    return unless @coupon_code and coupon = Coupon.find_by_code(@coupon_code.upcase)
    coupon.create_discount(self)
  end
end
