# encoding: utf-8
#

require 'spec_helper'

describe Spree::Adjustment, :type => :model do

  let(:order) { Spree::Order.new }

  before do
    allow(order).to receive(:update!)
  end

  let(:adjustment) { Spree::Adjustment.create!(label: 'Adjustment', adjustable: order, order: order, amount: 5) }

  context '#create & #destroy' do
    let(:adjustment) { Spree::Adjustment.new(label: "Adjustment", amount: 5, order: order, adjustable: create(:line_item)) }

    it 'calls #update_adjustable_adjustment_total' do
      expect(adjustment).to receive(:update_adjustable_adjustment_total).twice
      adjustment.save
      adjustment.destroy
    end
  end

  context '#save' do
    let(:adjustment) { Spree::Adjustment.create(label: "Adjustment", amount: 5, order: order, adjustable: create(:line_item)) }

    it 'touches the adjustable' do
      expect(adjustment.adjustable).to receive(:touch)
      adjustment.save
    end
  end

  context "adjustment state" do
    let(:adjustment) { create(:adjustment, order: order, state: 'open') }

    context "#closed?" do
      it "is true when adjustment state is closed" do
        adjustment.state = "closed"
        expect(adjustment).to be_closed
      end

      it "is false when adjustment state is open" do
        adjustment.state = "open"
        expect(adjustment).to_not be_closed
      end
    end
  end

  context '#currency' do
    it 'returns the globally configured currency' do
      expect(adjustment.currency).to eq 'USD'
    end
  end

  context "#display_amount" do
    before { adjustment.amount = 10.55 }

    context "with display_currency set to true" do
      before { Spree::Config[:display_currency] = true }

      it "shows the currency" do
        expect(adjustment.display_amount.to_s).to eq "$10.55 USD"
      end
    end

    context "with display_currency set to false" do
      before { Spree::Config[:display_currency] = false }

      it "does not include the currency" do
        expect(adjustment.display_amount.to_s).to eq "$10.55"
      end
    end

    context "with currency set to JPY" do
      context "when adjustable is set to an order" do
        before do
          expect(order).to receive(:currency).and_return('JPY')
          adjustment.adjustable = order
        end

        it "displays in JPY" do
          expect(adjustment.display_amount.to_s).to eq "¥11"
        end
      end

      context "when adjustable is nil" do
        it "displays in the default currency" do
          expect(adjustment.display_amount.to_s).to eq "$10.55"
        end
      end
    end
  end

  context '#update!' do
    context "when adjustment is closed" do
      before { expect(adjustment).to receive(:closed?).and_return(true) }

      it "does not update the adjustment" do
        expect(adjustment).to_not receive(:update_column)
        adjustment.update!
      end
    end

    context "when adjustment is open" do
      before { expect(adjustment).to receive(:closed?).and_return(false) }

      it "updates the amount" do
        expect(adjustment).to receive(:adjustable).and_return(double("Adjustable")).at_least(1).times
        expect(adjustment).to receive(:source).and_return(double("Source")).at_least(1).times
        expect(adjustment.source).to receive("compute_amount").with(adjustment.adjustable).and_return(5)
        expect(adjustment).to receive(:update_columns).with(amount: 5, updated_at: kind_of(Time))
        adjustment.update!
      end
    end
  end

end
