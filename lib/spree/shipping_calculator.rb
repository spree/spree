module Spree #:nodoc:
  module ShippingCalculator

    def mark_shipped
      inventory_units.each do |inventory_unit|
        inventory_unit.ship!
      end
    end
        
    # collection of available shipping countries
    def shipping_countries
      ShippingMethod.all.collect { |method| method.zone.country_list }.flatten.uniq.sort_by {|item| item.send 'name'}
    end
    
    private
=begin
    def before_shipment
      # automatically calculate shipping if there is only a single shipping method
      if shipping_methods.size == 1
        self.shipments << Shipment.create(:order => self, :shipping_method => shipping_methods.first)
        self.state = "creditcard"
        save
      end
    end
=end

  end
end