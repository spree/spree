require File.dirname(__FILE__) + '/../spec_helper'

describe User do

  context "validation" do
    it { should have_valid_factory(:user) }
  end

end
