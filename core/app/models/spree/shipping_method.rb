module Spree
  class ShippingMethod < ActiveRecord::Base
    include Spree::Core::CalculatedAdjustments
    DISPLAY = [:both, :front_end, :back_end]

    default_scope where(:deleted_at => nil)

    has_many :shipments
    validates :name, :presence => true

    has_many :shipping_method_categories
    has_many :shipping_categories, :through => :shipping_method_categories

    has_and_belongs_to_many :zones

    attr_accessible :name, :zones, :display_on, :shipping_category_id,
                    :match_none, :match_one, :match_all

    def adjustment_label
      I18n.t(:shipping)
    end

    def zone
      p "DEPRECATION WARNING: ShippingMethod#zone is no longer correct. Multiple zones need to be supported"
      Rails.logger.error "DEPRECATION WARNING: ShippingMethod#zone is no longer correct. Multiple zones need to be supported"
      zones.first
    end

    def zone=(zone)
      p "DEPRECATION WARNING: ShippingMethod#zone is no longer correct. Multiple zones need to be supported"
      Rails.logger.error "DEPRECATION WARNING: ShippingMethod#zone= is no longer correct. Multiple zones need to be supported"
      zones = zone
    end

    def include?(address)
      return false unless address
      zones.any? do |zone|
        zone.include?(address)
      end
    end

    def build_tracking_url(tracking)
      tracking_url.gsub(/:tracking/, tracking) unless tracking.blank? || tracking_url.blank?
    end
  end
end
