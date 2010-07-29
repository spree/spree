class ShippingMethod < ActiveRecord::Base
  DISPLAY =  [:both, :front_end, :back_end]
  belongs_to :zone
  has_many :shipping_rates
  has_many :shipments

  has_calculator

  def calculate_cost(shipment)
    rate_calculators = {}
    shipping_rates.each do |sr|
      rate_calculators[sr.shipping_category_id] = sr.calculator
    end

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
    _zone = Zone.cached.detect {|zone| zone.id == self.zone_id }
    available?(order, display_on) && _zone && _zone.include?(order.ship_address)
  end

  def self.all_available(order, display_on=nil)
    cached.select { |method| method.available_to_order?(order,display_on)}
  end

  def self.cached
    if Rails.configuration.cache_classes
      Rails.cache.fetch("ShippingMethod.all") { ShippingMethod.all(:include => :calculator) }
    else
      ShippingMethod.all(:include => :calculator)
    end
  end

end
