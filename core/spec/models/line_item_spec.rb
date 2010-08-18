require 'spec_helper'

describe LineItem do
  context "#save" do
    it "should call order#update!" do
      order = mock_model(Order, :update! => nil)
      line_item = Fabricate(:line_item, :order => order)
      order.should_receive(:update!)
      line_item.save
    end
  end
end