require File.dirname(__FILE__) + '/../spec_helper'

describe Tracker do

  context "validations" do
    it { should have_valid_factory(:tracker) }
  end

end
