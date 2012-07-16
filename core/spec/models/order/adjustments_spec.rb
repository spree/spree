require 'spec_helper'
describe Spree::Order do
  let(:order) { Spree::Order.new }

  context "clear_adjustments" do
    it "should destroy all previous tax adjustments" do
      adjustment_1 = stub
      adjustment_1.should_receive :destroy
      adjustment_2 = stub
      adjustment_2.should_receive :destroy

      order.stub_chain :adjustments, :tax => [adjustment_1]
      order.stub :price_adjustments => [adjustment_2]
      order.clear_adjustments!
    end
  end
end

