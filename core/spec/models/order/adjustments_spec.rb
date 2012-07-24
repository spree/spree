require 'spec_helper'
describe Spree::Order do
  let(:order) { Spree::Order.new }

  context "clear_adjustments" do
    it "should destroy all previous tax adjustments" do
      adjustment = stub
      adjustment.should_receive :destroy

      order.stub_chain :adjustments, :tax => [adjustment]
      order.clear_adjustments!
    end

    it "should destroy all price adjustments" do
      adjustment = stub
      adjustment.should_receive :destroy

      order.stub :price_adjustments => [adjustment]
      order.clear_adjustments!
    end
  end
end

