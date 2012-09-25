require 'spec_helper'

describe Spree::Order do
  let(:order) { stub_model(Spree::Order) }

  context "#update!" do
    let(:line_items) { [mock_model(Spree::LineItem, :amount => 5) ]}

    context "when there are update hooks" do
      before { Spree::Order.register_update_hook :foo }
      after { Spree::Order.update_hooks.clear }
      it "should call each of the update hooks" do
        order.should_receive :foo
        order.update!
      end
    end
  end
end
