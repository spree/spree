module Spree
  class StateMachineGenerator < Rails::Generators::Base
    def self.source_paths
      paths = self.superclass.source_paths
      paths << Spree::Core::Engine.paths["app/models"].expanded[0]
      paths.flatten
    end

    def copy
      destination = "app/models/spree/order/state_machine.rb"
      copy_file "spree/order/state_machine.rb", destination
      inject_into_file destination, :before => "Spree::Order.class_eval do\n" do
%Q{
# This file overrides the default state machine for Spree's Order model.
# For information about customizing the checkout process, please read
# the Checkout guide: http://guides.spreecommerce.com/checkout.html
}.gsub(/^\n/, '')
      end
    end
  end
end

