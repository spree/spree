module Spree #:nodoc:
  module ShippingCalculator

    # modify the transitions in core - go to shipping after address (instead of cc payment)
    fsm = Order.state_machines['state']
    fsm.states << "shipment"
    fsm.events['next'].transitions.delete_if { |t| t.options[:to] == "creditcard" && t.options[:from] == "address" }
    fsm.events['next'].transition(:to => 'shipment', :from => 'address')
    fsm.events['next'].transition(:to => 'creditcard', :from => 'shipment')
    fsm.events['previous'].transition(:to => 'address', :from => 'shipment')
    fsm.events['previous'].transition(:to => 'shipment', :from => 'creditcard')
    fsm.after_transition :to => 'shipment', :do => :before_shipment
    fsm.events['edit'].transition(:to => 'in_progress', :from => 'shipment')
    fsm.after_transition(:to => 'shipment', :do => lambda {|order| order.update_attribute(:tax_amount, order.calculate_tax)})

    fsm.events['ship'] = PluginAWeek::StateMachine::Event.new(fsm, "ship")
    fsm.events['ship'].transition(:to => 'shipped', :from => 'captured')
    
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