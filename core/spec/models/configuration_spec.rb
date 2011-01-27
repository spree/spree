require File.dirname(__FILE__) + '/../spec_helper'

describe Configuration do

  context "validations" do
    it { should have_valid_factory(:configuration) }
  end

end
