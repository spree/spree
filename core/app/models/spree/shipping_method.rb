module Spree
  class ShippingMethod < ActiveRecord::Base
    include Spree::Core::CalculatedAdjustments
    DISPLAY = [:both, :front_end, :back_end]

    default_scope where(deleted_at: nil)

    has_many :shipments
    has_many :shipping_method_categories
    has_many :shipping_categories, through: :shipping_method_categories
    has_many :shipping_rates

    has_and_belongs_to_many :zones, :join_table => 'spree_shipping_methods_zones',
                                    :class_name => 'Spree::Zone',
                                    :foreign_key => 'shipping_method_id'

    attr_accessible :name, :admin_name, :zones, :display_on, :shipping_category_id,
                    :match_none, :match_one, :match_all, :tracking_url

    validates :name, presence: true

    validate :at_least_one_shipping_category

    def adjustment_label
      Spree.t(:shipping)
    end

    def zone
      ActiveSupport::Deprecation.warn("[SPREE] ShippingMethod#zone is no longer correct. Multiple zones need to be supported")
      zones.first
    end

    def zone=(zone)
      ActiveSupport::Deprecation.warn("[SPREE] ShippingMethod#zone= is no longer correct. Multiple zones need to be supported")
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

    def self.calculators
      spree_calculators.send(model_name_without_spree_namespace).select{|c| c.name.start_with?("Spree::Calculator::Shipping::")}
    end

    # Some shipping methods are only meant to be set via backend
    def frontend?
      self.display_on != "back_end"
    end

    private
      def at_least_one_shipping_category
        if self.shipping_categories.empty?
          self.errors[:base] << "You need to select at least one shipping category"
        end
      end

      def self.on_backend_query
        "#{table_name}.display_on != 'front_end' OR #{table_name}.display_on IS NULL"
      end

      def self.on_frontend_query
        "#{table_name}.display_on != 'back_end' OR #{table_name}.display_on IS NULL"
      end
  end
end
