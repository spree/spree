module Spree #:nodoc:
  module ShippingCalculator

    # modify the transitions in core - go to shipping first (before creditcard)
    fsm = Order.state_machines['state']
    fsm.states << "shipment"
    fsm.events['next'].transitions.delete_if { |t| t.options[:to] == "creditcard" && t.options[:from] == "in_progress" }
    fsm.events['next'].transition(:to => 'shipment', :from => 'in_progress')
    fsm.events['next'].transition(:to => 'shipping_method', :from => 'shipment')
    fsm.events['next'].transition(:to => 'creditcard', :from => 'shipping_method')
    # skip right to creditcard step if there are no shipping methods at all (ex. store sells only electronic downloads)
    fsm.after_transition :to => 'shipment', :do => lambda { |order| order.update_attribute(:state, "creditcard") if ShippingMethod.all.empty? }
    fsm.events['edit'].transition(:to => 'in_progress', :from => ['shipment', 'shipping_method'])
    fsm.after_transition :to => 'shipping_method', :do => lambda {|order| order.update_attribute(:tax_amount, order.calculate_tax)}
    fsm.after_transition :to => 'shipped', :do => :mark_shipped

    fsm.events['ship'] = PluginAWeek::StateMachine::Event.new(fsm, "ship")
    fsm.events['ship'].transition(:to => 'shipped', :from => 'paid')

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