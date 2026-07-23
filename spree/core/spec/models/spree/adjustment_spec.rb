require 'spec_helper'

# Spree::Adjustment is a deprecated reader over frozen pre-6.0 data: nothing
# in core writes or recalculates it anymore (typed adjustment lines replaced
# it), and it is removed entirely in 6.1. These examples pin the behavior the
# deprecation window still guarantees.
describe Spree::Adjustment, type: :model do
  let(:order) { create(:order) }
  let(:adjustment) { create(:adjustment, order: order, adjustable: order, amount: 5) }

  it 'still loads and persists legacy rows' do
    expect(adjustment).to be_persisted
    expect(adjustment.prefixed_id).to start_with('adj_')
  end

  it 'no longer triggers recalculation on create or destroy' do
    expect_any_instance_of(Spree::OrderUpdater).not_to receive(:update)

    create(:adjustment, order: order, adjustable: order).destroy!
  end

  describe 'state machine (kept for the deprecation window)' do
    it 'transitions between open and closed' do
      expect(adjustment).to be_open
      adjustment.close
      expect(adjustment).to be_closed
      adjustment.open
      expect(adjustment).to be_open
    end
  end

  describe '#update!' do
    it 'does not recompute closed adjustments' do
      adjustment.close

      expect { adjustment.update! }.not_to change { adjustment.reload.amount }
    end

    it 'does not recompute sourceless (manual) adjustments' do
      manual = create(:adjustment, order: order, adjustable: order, source: nil, amount: 7)

      expect { manual.update! }.not_to change { manual.reload.amount }
    end
  end

  describe 'scopes' do
    it 'still partitions frozen rows by source and eligibility' do
      tax_row = create(:adjustment, order: order, adjustable: order)
      manual_row = create(:adjustment, order: order, adjustable: order, source: nil, eligible: false)

      expect(described_class.tax).to include(tax_row)
      expect(described_class.eligible).to include(tax_row)
      expect(described_class.eligible).not_to include(manual_row)
      expect(described_class.non_tax).to include(manual_row)
    end
  end

  describe 'deprecated association readers' do
    it 'warns on the order readers' do
      expect(Spree::Deprecation).to receive(:warn).with(/Spree::Order#adjustments/)
      order.adjustments

      expect(Spree::Deprecation).to receive(:warn).with(/Spree::Order#all_adjustments/)
      order.all_adjustments
    end

    it 'warns on the line item and shipment readers' do
      expect(Spree::Deprecation).to receive(:warn).with(/Spree::LineItem#adjustments/)
      build(:line_item).adjustments

      expect(Spree::Deprecation).to receive(:warn).with(/Spree::Shipment#adjustments/)
      build(:shipment).adjustments
    end
  end
end
