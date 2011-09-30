require 'spec_helper'

describe PromotionRule do

  it "should force developer to implement eligible? method" do
    lambda { MyRule.new.eligible? }.should raise_error
  end

end
