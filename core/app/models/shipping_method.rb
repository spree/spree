class ShippingMethod < ActiveRecord::Base
  DISPLAY =  [:both, :front_end, :back_end]
  belongs_to :zone
  has_many :shipments

  calculated_adjustments

  def available?(order, display_on=nil)
    (self.display_on == display_on.to_s || self.display_on.blank?) && calculator.available?(order)
  end

  def available_to_order?(order, display_on=nil)
    available?(order,display_on) && zone && zone.include?(order.ship_address)
  end

  def self.all_available(order, display_on=nil)
    all.select { |method| method.available_to_order?(order,display_on)}
  end

end
