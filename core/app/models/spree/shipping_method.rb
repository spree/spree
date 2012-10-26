module Spree
  class ShippingMethod < ActiveRecord::Base
    DISPLAY = [:both, :front_end, :back_end]

    default_scope where(:deleted_at => nil)

    has_many :shipments
    validates :name, :zone, :presence => true

    belongs_to :shipping_category
    belongs_to :zone

    attr_accessible :name, :zone_id, :display_on, :shipping_category_id,
                    :match_none, :match_one, :match_all

    calculated_adjustments

    def available?(order, display_on = nil)
      displayable?(display_on) && calculator.available?(order)
    end

    def displayable?(display_on)
      (self.display_on == display_on.to_s || self.display_on.blank?)
    end

    def calculator_available?(order)
      calculator.available?(order)
    end

    def within_zone?(order)
      zone && zone.include?(order.ship_address)
    end

    def available_to_order?(order, display_on= nil)
      available?(order, display_on) &&
      within_zone?(order) &&
      category_match?(order)
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

    def self.all_available(order, display_on = nil)
      all.select { |method| method.available_to_order?(order,display_on) }
    end
  end
end
