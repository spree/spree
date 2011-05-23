require 'spec_helper'

describe Promotion::Actions::CreateLineItems do
  let(:order) { mock_model(Order, :user => nil) }

  # From promotion spec:
  context "#perform" do
    let(:order) { Order.new }
    let(:promotion) { Promotion.new }
    let(:action) { Promotion::Actions::CreateLineItems.new }

    before do
      promotion.promotion_actions = [action]
      action.stub(:promotion => promotion)
    end


    it "should not create line items when order is not eligible"

    it "should create line items when order is eligible"

  end

end

