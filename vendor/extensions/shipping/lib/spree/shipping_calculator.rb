module Spree #:nodoc:
  module ShippingCalculator

    # modify the transitions in core - go to shipping after address (instead of cc payment)
    Order.state_machines['state'].states << "shipment"
    Order.state_machines['state'].events['next'].transitions.delete_if { |t| t.options[:to] == "creditcard_payment" && t.options[:from] == "address" }
    Order.state_machines['state'].events['next'].transition(:to => 'shipment', :from => 'address')
    Order.state_machines['state'].events['next'].transition(:to => 'creditcard_payment', :from => 'shipment')
    Order.state_machines['state'].events['previous'].transition(:to => 'address', :from => 'shipment')
    Order.state_machines['state'].after_transition :to => 'shipment', :do => :before_shipment
    Order.state_machines['state'].events['edit'].transition(:to => 'in_progress', :from => 'shipment')
    Order.state_machines['state'].after_transition(:to => 'shipment', :do => lambda {|order| order.update_attribute(:tax_amount, order.calculate_tax)})

    def shipping_methods
      methods = ShippingMethod.all
      methods.select { |method| method.zone.include?(address) }
    end
    
    # collection of available shipping countries
    def shipping_countries
      ShippingMethod.all.collect { |method| method.zone.country_list }.flatten.uniq.sort_by {|item| item.send 'name'}
    end
    
    private
    def before_shipment
      # skip this step if there are no shipping methods
      update_attribute(:state, "creditcard_payment") if shipping_methods.empty?
      # automatically calculate shipping if there is only a single shipping method
      if shipping_methods.size == 1
        self.shipments << Shipment.create(:order => self, :shipping_method => shipping_methods.first)
        self.state = "creditcard_payment"
        save
      end
    end

  end
end