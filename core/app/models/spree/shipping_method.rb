class Spree::ShippingMethod < ActiveRecord::Base
  DISPLAY =  [:both, :front_end, :back_end]
  belongs_to :zone
  has_many :shipments
  validates :name, :calculator, :zone, :presence => true

  calculated_adjustments

  def available?(order, display_on=nil)
    display_check = (self.display_on == display_on.to_s || self.display_on.blank?)
    calculator_check = calculator.available?(order)
    display_check && calculator_check
  end

  def available_to_order?(order, display_on=nil)
    availability_check = available?(order,display_on)
    zone_check = zone && zone.include?(order.ship_address)
    availability_check && zone_check
  end

  def self.all_available(order, display_on=nil)
    all.select { |method| method.available_to_order?(order,display_on) }
  end
end
