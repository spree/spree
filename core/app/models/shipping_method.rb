class ShippingMethod < ActiveRecord::Base
  DISPLAY =  [:both, :front_end, :back_end]
  belongs_to :zone
  has_many :shipments

  create_adjustments

  def calculate_cost(shipment)
    rate_calculators = {}

    calculated_costs = shipment.line_items.group_by{|li|
      li.product.shipping_category_id
    }.map{ |shipping_category_id, line_items|
      calc = rate_calculators[shipping_category_id] || self.calculator
      calc.compute(line_items)
    }.sum

    return(calculated_costs)
  end

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
