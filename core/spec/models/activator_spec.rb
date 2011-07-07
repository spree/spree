require File.dirname(__FILE__) + '/../spec_helper'

describe Activator do

  context "event_names" do
    specify { Activator.event_names.is_a?(Array) }
    specify { Activator.event_names.all?{|n| n.is_a?(String)} }
  end

  context "register_event_name" do
    it "adds the name to event_names" do
      Activator.register_event_name('spree.new_event')
      Activator.event_names.should include('spree.new_event')
    end
  end

end
