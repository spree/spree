require 'spec_helper'

describe Adjustment do
  let(:order) { mock_model(Order, :update! => nil) }
  context "#save" do
    it "should call order#update!" do
      adjustment = Adjustment.new(:order => order, :amount => 10, :description => "Foo")
      order.should_receive(:update!)
      adjustment.save
    end
  end
end