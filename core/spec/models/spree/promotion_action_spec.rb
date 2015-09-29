require 'spec_helper'

describe Spree::PromotionAction, :type => :model do

  it "should force developer to implement 'perform' method" do
    expect { MyAction.new.perform }.to raise_error(NameError)
  end

end

