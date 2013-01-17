require 'spec_helper'

describe Spree::PromotionAction do

  it "should force developer to implement 'perform' method" do
    lambda { MyAction.new.perform }.should raise_error
  end

end

