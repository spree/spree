module Spree
  class ShippingMethod < ActiveRecord::Base
    DISPLAY =  [:both, :front_end, :back_end]
    belongs_to :zone
    has_many :shipments
    validates :name, :calculator, :zone, :presence => true
    belongs_to :shipping_category

    attr_accessible :name, :zone_id, :display_on, :shipping_category_id,
                    :match_none, :match_one, :match_all

    calculated_adjustments

    def available?(order, display_on=nil)
      display_check = (self.display_on == display_on.to_s || self.display_on.blank?)
      calculator_check = calculator.available?(order)
      display_check && calculator_check
    end

    def available_to_order?(order, display_on=nil)
      availability_check = available?(order,display_on)
      zone_check = zone && zone.include?(order.ship_address)
      category_check = category_match?(order)
      availability_check && zone_check && category_check
    end

    # Indicates whether or not the category rules for this shipping method
    # are satisfied (if applicable)
    def category_match?(order)
      return true if shipping_category.nil?

      if match_all
        order.products.all? { |p| p.shipping_category == shipping_category }
      elsif match_one
        order.products.any? { |p| p.shipping_category == shipping_category }
      elsif match_none
        order.products.all? { |p| p.shipping_category != shipping_category }
      end
    end

    def self.all_available(order, display_on=nil)
      all.select { |method| method.available_to_order?(order,display_on) }
    end
  end
end
