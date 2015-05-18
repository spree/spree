# encoding: utf-8
#

require 'spec_helper'

describe Spree::Adjustment, :type => :model do

  let(:order) { Spree::Order.new.tap(&:save!) }

  before do
    allow(order).to receive(:update!)
  end

  let(:adjustment) { order.all_adjustments.build(label: 'Adjustment', adjustable: order, amount: 5) }

  context '#create & #destroy' do
    let(:order) { create(:order) }
    let(:adjustment) { order.create_adjustment!(label: 'Adjustment', amount: 5, adjustable: create(:line_item, order: order)) }

    it 'calls #update_adjustable_adjustment_total' do
      expect(adjustment).to receive(:update_adjustable_adjustment_total)
      adjustment.destroy
    end
  end

  context '#save' do
    let(:order) { create(:order) }
    let(:adjustment) { order.create_adjustment!(label: 'Adjustment', amount: 5, adjustable: create(:line_item, order: order)) }

    it 'touches the adjustable' do
      expect(adjustment.adjustable).to receive(:touch)
      adjustment.save!
    end
  end

  context 'non_tax scope' do
    subject do
      order.all_adjustments.non_tax.to_a
    end

    let!(:tax_adjustment) { order.create_adjustment!(adjustable: order, amount: 100, label: 'Tax', source: create(:tax_rate)) }
    let!(:non_tax_adjustment_with_source) { order.create_adjustment!(adjustable: order, amount: 100, label: 'Other', source_type: 'Spree::Order', source_id: nil) }
    let!(:non_tax_adjustment_without_source) { order.create_adjustment!(adjustable: order, amount: 100, label: 'Other', source: nil) }

    it 'select non-tax adjustments' do
      expect(subject).to_not include tax_adjustment
      expect(subject).to     include non_tax_adjustment_with_source
      expect(subject).to     include non_tax_adjustment_without_source
    end
  end

  context "adjustment state" do
    let(:adjustment) { Spree::Adjustment.new }

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

  context '#adjustable' do
    let(:object) do
      order.all_adjustments.build(
        label:           'Test Adjustment',
        adjustable_type: adjustable_type,
        adjustable_id:   adjustable_id,
      )
    end

    let(:adjustable_id) { 1 }

    subject { object.adjustable }

    context 'when adjustable_type is "Spree::Order"' do
      let(:adjustable_type) { 'Spree::Order' }

      it { should be(order) }
    end

    context 'when adjustable_type is "Spree::LineItem"' do
      let(:adjustable_type) { 'Spree::LineItem'                         }
      let(:line_item)       { order.line_items.build(id: adjustable_id) }

      context 'when shipment with adjustable_id exists on order' do
        it { should be(line_item) }
      end

      context 'when shipment with adjustable_id does NOT exist in order' do
        let(:adjustable_id) { 2 }

        it 'raises an AdjustableLoookupError' do
          expect { subject }.to raise_error(Spree::Adjustment::AdjustableLookupError, 'Spree::LineItem with id 2 not found')
        end
      end
    end

    context 'when adjustable_type is "Spree::Shipment"' do
      let(:adjustable_type) { 'Spree::Shipment'                        }
      let(:shipment)        { order.shipments.build(id: adjustable_id) }

      context 'when shipment with adjustable_id exists on order' do
        it { should be(shipment) }
      end

      context 'when shipment with adjustable_id does NOT exist in order' do
        let(:adjustable_id) { 2 }

        it 'raises an AdjustableLoookupError' do
          expect { subject }.to raise_error(Spree::Adjustment::AdjustableLookupError, 'Spree::Shipment with id 2 not found')
        end
      end
    end

    context 'when adjustable_type is anything else' do
      let(:adjustable_type) { 'something else' }

      it 'raises an AdjustableLookupError' do
        expect { subject }.to raise_error(Spree::Adjustment::AdjustableLookupError, 'No strategy to load adjustable_type: "something else"')
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
    # Regression test for #6689
    it "correctly calculates for adjustments with no source" do
      expect(adjustment.update!).to eq 5
    end

    context "when adjustment is closed" do
      before { expect(adjustment).to receive(:closed?).and_return(true) }

      it 'does not update the adjustment' do
        expect(adjustment).to_not receive(:update_column)
        expect(adjustment.update!).to eql(adjustment.amount)
      end
    end

    context 'when adjustment is open' do
      before { expect(adjustment).to receive(:closed?).and_return(false) }

      context 'and source is present' do
        it 'updates the amount' do
          expect(adjustment).to receive(:adjustable).and_return(double("Adjustable")).at_least(1).times
          expect(adjustment).to receive(:source).and_return(double("Source")).at_least(1).times
          expect(adjustment.source).to receive("compute_amount").with(adjustment.adjustable).and_return(5)
          expect(adjustment).to receive(:update_columns).with(amount: 5, updated_at: kind_of(Time))
          expect(adjustment.update!).to be(5)
        end
      end

      context 'and source is not present' do
        it 'does not update the adjustment' do
          expect(adjustment).to_not receive(:update_column)
          expect(adjustment.update!).to eql(adjustment.amount)
        end
      end
    end
  end
end
