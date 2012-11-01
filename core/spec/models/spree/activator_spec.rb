require 'spec_helper'

describe Spree::Activator do

  context "register_event_name" do
    it "adds the name to event_names" do
      Spree::Activator.register_event_name('spree.new_event')
      Spree::Activator.event_names.should include('spree.new_event')
    end
  end

end
