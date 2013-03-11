module Spree
  class ShippingMethod < ActiveRecord::Base
    include Spree::Core::CalculatedAdjustments
    DISPLAY = [:both, :front_end, :back_end]

    default_scope where(:deleted_at => nil)

    has_many :shipments
    validates :name, :zone, :presence => true

    belongs_to :shipping_category
    belongs_to :zone

    attr_accessible :name, :zone_id, :display_on, :shipping_category_id,
                    :match_none, :match_one, :match_all, :tracking_url

    def adjustment_label
      I18n.t(:shipping)
    end

    def available?(order)
      calculator.available?(order)
    end

    def within_zone?(order)
      zone && zone.include?(order.ship_address)
    end

    def available_to_order?(order)
      available?(order) &&
      within_zone?(order) &&
      category_match?(order) &&
      currency_match?(order)
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

    def currency_match?(order)
      calculator_currency.nil? || calculator_currency == order.currency
    end

    def calculator_currency
      calculator.preferences[:currency]
    end

    def self.all_available(order)
      all.select { |method| method.available_to_order?(order) }
    end

    def build_tracking_url(tracking)
      tracking_url.gsub(/:tracking/, tracking) unless tracking.blank? || tracking_url.blank?
    end
  end
end
