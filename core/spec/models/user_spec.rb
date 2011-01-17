require File.dirname(__FILE__) + '/../spec_helper'

describe User do

  context "factory_girl" do
    specify { Factory(:user).new_record?.should be_false }
  end

end
