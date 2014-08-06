require 'spec_helper'

module Spree
  describe Exchange do
    let(:order) { Spree::Order.new }

    let(:reimbursement_item_1) { build(:exchange_reimbursement_item) }
    let(:reimbursement_item_2) { build(:exchange_reimbursement_item) }
    let(:reimbursement_items) { [reimbursement_item_1, reimbursement_item_2] }
    let(:exchange) { Exchange.new(order, reimbursement_items) }

    describe "#description" do
      before do
        reimbursement_item_1.stub(:variant) { double(options_text: "foo") }
        reimbursement_item_1.stub(:exchange_variant) { double(options_text: "bar") }
        reimbursement_item_2.stub(:variant) { double(options_text: "baz") }
        reimbursement_item_2.stub(:exchange_variant) { double(options_text: "qux") }
      end

      it "describes the return items' change in options" do
        expect(exchange.description).to match /foo => bar/
        expect(exchange.description).to match /baz => qux/
      end
    end

    describe "#display_amount" do
      it "is the total amount of all return items" do
        expect(exchange.display_amount).to eq Spree::Money.new(0.0)
      end
    end

    describe "#perform!" do
      let(:reimbursement_item) { create(:exchange_reimbursement_item) }
      let(:reimbursement_items) { [reimbursement_item] }
      let(:order) { reimbursement_item.reimbursement.order }
      subject { exchange.perform! }
      before { reimbursement_item.exchange_variant.stock_items.first.adjust_count_on_hand(20) }

      it "creates shipments for the order with the return items exchange inventory units" do
        expect { subject }.to change { order.shipments.count }.by(1)
        new_shipment = order.shipments.last
        expect(new_shipment).to be_ready
        new_inventory_units = new_shipment.inventory_units
        expect(new_inventory_units.count).to eq 1
        expect(new_inventory_units.first.original_reimbursement_item).to eq reimbursement_item
        expect(new_inventory_units.first.line_item).to eq reimbursement_item.inventory_unit.line_item
      end
    end

    describe "#to_key" do # for dom_id
      it { expect(Exchange.new(nil, nil).to_key).to be_nil }
    end

    describe ".param_key" do # for dom_id
      it { expect(Exchange.param_key).to eq "spree_exchange" }
    end

    describe ".model_name" do # for dom_id
      it { expect(Exchange.model_name).to eq Spree::Exchange }
    end

  end
end
