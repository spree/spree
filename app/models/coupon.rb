class Coupon < ActiveRecord::Base
  has_many  :credits,    :as => :adjustment_source
  has_calculator

  validates_presence_of :code
  
  def eligible?(order)
    return false if expires_at and Time.now > expires_at
    return false if usage_limit and credits.count >= usage_limit
    # TODO - also check items in the order (once we support product groups for coupons)
    true
  end
    
  def create_discount(order)
    if eligible?(order) and amount = calculator.compute(order)
      amount = order.item_total if amount > order.item_total
      order.coupon_credits.reload.clear unless combine? and order.coupon_credits.all? { |credit| credit.adjustment_source.combine? }
      order.save
      credits.create({
          :order => order, 
          :amount => amount,
          :description => "#{I18n.t(:coupon)} (#{code})"
        })
    end
  end
end
