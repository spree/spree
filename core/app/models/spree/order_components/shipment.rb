require 'active_support/concern'

module Spree
  module OrderComponents
    module Shipment
      extend ActiveSupport::Concern

      included do
        attr_accessible :shipping_method_id

        belongs_to :shipping_method, :class_name => "Spree::ShippingMethod"
        has_many :shipments, :dependent => :destroy
        accepts_nested_attributes_for :shipments

        validate :has_available_shipment

        def available_shipping_methods(display_on = nil)
          return [] unless ship_address
          ShippingMethod.all_available(self, display_on)
        end

        # convenience method since many stores will not allow user to create multiple shipments
        def shipment
          @shipment ||= shipments.last
        end

        # Clear shipment when transitioning to delivery step of checkout if the
        # current shipping address is not eligible for the existing shipping method
        def remove_invalid_shipments!
          shipments.each { |s| s.destroy unless s.shipping_method.available_to_order?(self) }
        end

        # Creates a new shipment (adjustment is created by shipment model)
        def create_shipment!
          shipping_method(true)
          if shipment.present?
            shipment.update_attributes!(:shipping_method => shipping_method)
          else
            self.shipments << Shipment.create!({ :order => self,
                                               :shipping_method => shipping_method,
                                               :address => self.ship_address,
                                               :inventory_units => self.inventory_units}, :without_protection => true)
          end

        end


        private
        def has_available_shipment
          return unless :address == state_name.to_sym
          return unless ship_address && ship_address.valid?
          errors.add(:base, :no_shipping_methods_available) if available_shipping_methods.empty?
        end
      end
    end
  end
end
