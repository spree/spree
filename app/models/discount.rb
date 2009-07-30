class Discount < ActiveRecord::Base    
  after_save :update_credit
  
  has_one :credit, :as => :creditable, :dependent => :destroy
  belongs_to :coupon
  belongs_to :checkout
  
  validates_presence_of :coupon_id
  validates_presence_of :checkout_id   

  def update_credit
    amount = coupon.calculator.calculate_discount(checkout)
    self.destroy and return unless coupon.eligible?(checkout) and amount    
    return credit.update_attribute("amount", amount) if credit  
    self.credit = Credit.create(:amount => amount, :description => "#{I18n.t('coupon')} (#{coupon.code})", :order => checkout.order)
  end
end
