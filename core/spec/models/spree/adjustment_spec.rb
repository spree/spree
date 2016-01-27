# encoding: utf-8
#

require 'spec_helper'

describe Spree::Adjustment, :type => :model do

  let(:order) { Spree::Order.new }

  before do
    allow(order).to receive(:update!)
  end

  let(:adjustment) { Spree::Adjustment.create!(label: 'Adjustment', adjustable: order, order: order, amount: 5) }

  describe 'scopes' do
    describe '.for_complete_order' do
      let(:complete_order) { Spree::Order.create! completed_at: Time.current }
      let(:incomplete_order) { Spree::Order.create! completed_at: nil }
      let(:adjustment_for_complete_order) { Spree::Adjustment.create!(label: 'Adjustment', adjustable: complete_order, order: complete_order, amount: 5) }
      let(:adjustment_for_incomplete_order) { Spree::Adjustment.create!(label: 'Adjustment', adjustable: incomplete_order, order: incomplete_order, amount: 5) }

      subject { Spree::Adjustment.for_complete_order }

      it { is_expected.to include(adjustment_for_complete_order) }
      it { is_expected.to_not include(adjustment_for_incomplete_order) }
    end

    describe '.for_incomplete_order' do
      let(:complete_order) { Spree::Order.create! completed_at: Time.current }
      let(:incomplete_order) { Spree::Order.create! completed_at: nil }
      let(:adjustment_for_complete_order) { Spree::Adjustment.create!(label: 'Adjustment', adjustable: complete_order, order: complete_order, amount: 5) }
      let(:adjustment_for_incomplete_order) { Spree::Adjustment.create!(label: 'Adjustment', adjustable: incomplete_order, order: incomplete_order, amount: 5) }

      subject { Spree::Adjustment.for_incomplete_order }

      it { is_expected.to_not include(adjustment_for_complete_order) }
      it { is_expected.to include(adjustment_for_incomplete_order) }
    end
  end

  context '#create & #destroy' do
    let(:adjustment) { Spree::Adjustment.new(label: "Adjustment", amount: 5, order: order, adjustable: create(:line_item)) }

    it 'calls #update_adjustable_adjustment_total' do
      expect(adjustment).to receive(:update_adjustable_adjustment_total).twice
      adjustment.save
      adjustment.destroy
    end
  end

  context '#save' do
    let(:order) { Spree::Order.create! }
    let!(:adjustment) { Spree::Adjustment.create(label: "Adjustment", amount: 5, order: order, adjustable: order) }

    it 'touches the adjustable' do
      expect(adjustment.adjustable).to receive(:touch)
      adjustment.amount = 3
      adjustment.save
    end
  end

  describe 'non_tax scope' do
    subject do
      Spree::Adjustment.non_tax.to_a
    end

    let!(:tax_adjustment) { create(:adjustment, order: order, source: create(:tax_rate)) }
    let!(:non_tax_adjustment_with_source) { create(:adjustment, order: order, source_type: 'Spree::Order', source_id: nil) }
    let!(:non_tax_adjustment_without_source) { create(:adjustment, order: order, source: nil) }

    it 'select non-tax adjustments' do
      expect(subject).to_not include tax_adjustment
      expect(subject).to include non_tax_adjustment_with_source
      expect(subject).to include non_tax_adjustment_without_source
    end
  end

  describe 'competing_promos scope' do    
    before do
      allow_any_instance_of(Spree::Adjustment).to receive(:update_adjustable_adjustment_total).and_return(true)
    end

    subject do
      Spree::Adjustment.competing_promos.to_a
    end

    let!(:promotion_adjustment) { create(:adjustment, order: order, source_type: 'Spree::PromotionAction', source_id: nil) }
    let!(:custom_adjustment_with_source) { create(:adjustment, order: order, source_type: 'Custom', source_id: nil) }
    let!(:non_promotion_adjustment_with_source) { create(:adjustment, order: order, source_type: 'Spree::Order', source_id: nil) }
    let!(:non_promotion_adjustment_without_source) { create(:adjustment, order: order, source: nil) }

    context 'no custom source_types have been added to competing_promos' do
      before { Spree::Adjustment.competing_promos_source_types = ['Spree::PromotionAction'] }

      it 'selects promotion adjustments by default' do
        expect(subject).to include promotion_adjustment
        expect(subject).to_not include custom_adjustment_with_source
        expect(subject).to_not include non_promotion_adjustment_with_source
        expect(subject).to_not include non_promotion_adjustment_without_source
      end
    end

    context 'a custom source_type has been added to competing_promos' do
      before { Spree::Adjustment.competing_promos_source_types = ['Spree::PromotionAction', 'Custom'] }

      it 'selects adjustments with registered source_types' do
        expect(subject).to include promotion_adjustment
        expect(subject).to include custom_adjustment_with_source
        expect(subject).to_not include non_promotion_adjustment_with_source
        expect(subject).to_not include non_promotion_adjustment_without_source
      end
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

    it "shows the amount" do
      expect(adjustment.display_amount.to_s).to eq "$10.55"
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
