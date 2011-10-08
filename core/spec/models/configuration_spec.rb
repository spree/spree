require 'spec_helper'

describe Spree::Configuration do

  context "validations" do
    it { should have_valid_factory(:configuration) }
  end

end
