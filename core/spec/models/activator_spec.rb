require 'spec_helper'

describe Spree::Activator do

  context "event_names" do
    specify { Spree::Activator.event_names.is_a?(Array) }
    specify { Spree::Activator.event_names.all?{|n| n.is_a?(String)} }
  end

  context "register_event_name" do
    it "adds the name to event_names" do
      Spree::Activator.register_event_name('spree.new_event')
      Spree::Activator.event_names.should include('spree.new_event')
    end
  end

end
