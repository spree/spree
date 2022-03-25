require 'spec_helper'

describe Spree::Adjustment, type: :model do
  let(:order) { Spree::Order.new }
  let(:adjustment) { Spree::Adjustment.create!(label: 'Adjustment', adjustable: order, order: order, amount: 5) }

  before do
    allow(order).to receive(:update_with_updater!)
  end

  describe '#amount=' do
    let(:amount) { '1,599,99' }

    before { adjustment.amount = amount }

    it 'is expected to equal to localized number' do
      expect(adjustment.amount).to eq(Spree::LocalizedNumber.parse(amount))
    end
  end

  describe 'scopes' do
    describe '.for_complete_order' do
      subject { Spree::Adjustment.for_complete_order }

      let(:complete_order) { Spree::Order.create! completed_at: Time.current }
      let(:incomplete_order) { Spree::Order.create! completed_at: nil }
      let(:adjustment_for_complete_order) { Spree::Adjustment.create!(label: 'Adjustment', adjustable: complete_order, order: complete_order, amount: 5) }
      let(:adjustment_for_incomplete_order) { Spree::Adjustment.create!(label: 'Adjustment', adjustable: incomplete_order, order: incomplete_order, amount: 5) }

      it { is_expected.to include(adjustment_for_complete_order) }
      it { is_expected.not_to include(adjustment_for_incomplete_order) }
    end

    describe '.for_incomplete_order' do
      subject { Spree::Adjustment.for_incomplete_order }

      let(:complete_order) { Spree::Order.create! completed_at: Time.current }
      let(:incomplete_order) { Spree::Order.create! completed_at: nil }
      let(:adjustment_for_complete_order) { Spree::Adjustment.create!(label: 'Adjustment', adjustable: complete_order, order: complete_order, amount: 5) }
      let(:adjustment_for_incomplete_order) { Spree::Adjustment.create!(label: 'Adjustment', adjustable: incomplete_order, order: incomplete_order, amount: 5) }

      it { is_expected.not_to include(adjustment_for_complete_order) }
      it { is_expected.to include(adjustment_for_incomplete_order) }
    end
  end

  context '#create & #destroy' do
    let(:adjustment) { Spree::Adjustment.new(label: 'Adjustment', amount: 5, order: order, adjustable: create(:line_item)) }

    it 'calls #update_adjustable_adjustment_total' do
      expect(adjustment).to receive(:update_adjustable_adjustment_total).twice
      adjustment.save
      adjustment.destroy
    end
  end

  context '#save' do
    let(:order) { create(:order) }
    let!(:adjustment) { Spree::Adjustment.create(label: 'Adjustment', amount: 5, order: order, adjustable: order) }

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
      expect(subject).not_to include tax_adjustment
      expect(subject).to include non_tax_adjustment_with_source
      expect(subject).to include non_tax_adjustment_without_source
    end
  end

  describe 'competing_promos scope' do
    subject do
      Spree::Adjustment.competing_promos.to_a
    end

    before do
      allow_any_instance_of(Spree::Adjustment).to receive(:update_adjustable_adjustment_total).and_return(true)
    end

    let!(:promotion_adjustment) { create(:adjustment, order: order, source_type: 'Spree::PromotionAction', source_id: nil) }
    let!(:custom_adjustment_with_source) { create(:adjustment, order: order, source_type: 'Custom', source_id: nil) }
    let!(:non_promotion_adjustment_with_source) { create(:adjustment, order: order, source_type: 'Spree::Order', source_id: nil) }
    let!(:non_promotion_adjustment_without_source) { create(:adjustment, order: order, source: nil) }

    context 'no custom source_types have been added to competing_promos' do
      before { Spree::Adjustment.competing_promos_source_types = ['Spree::PromotionAction'] }

      it 'selects promotion adjustments by default' do
        expect(subject).to include promotion_adjustment
        expect(subject).not_to include custom_adjustment_with_source
        expect(subject).not_to include non_promotion_adjustment_with_source
        expect(subject).not_to include non_promotion_adjustment_without_source
      end
    end

    context 'a custom source_type has been added to competing_promos' do
      before { Spree::Adjustment.competing_promos_source_types = ['Spree::PromotionAction', 'Custom'] }

      it 'selects adjustments with registered source_types' do
        expect(subject).to include promotion_adjustment
        expect(subject).to include custom_adjustment_with_source
        expect(subject).not_to include non_promotion_adjustment_with_source
        expect(subject).not_to include non_promotion_adjustment_without_source
      end
    end
  end

  context 'adjustment state' do
    let(:adjustment) { create(:adjustment, order: order, state: 'open') }

    context '#closed?' do
      it 'is true when adjustment state is closed' do
        adjustment.state = 'closed'
        expect(adjustment).to be_closed
      end

      it 'is false when adjustment state is open' do
        adjustment.state = 'open'
        expect(adjustment).not_to be_closed
      end
    end
  end

  context '#currency' do
    let(:order) { Spree::Order.new(currency: 'EUR') }

    it 'returns the order currency' do
      expect(adjustment.currency).to eq 'EUR'
    end
  end

  context '#display_amount' do
    before { adjustment.amount = 10.55 }

    it 'shows the amount' do
      expect(adjustment.display_amount.to_s).to eq '$10.55'
    end

    context 'with currency set to JPY' do
      context 'when adjustable is set to an order' do
        before do
          expect(order).to receive(:currency).and_return('JPY')
          adjustment.adjustable = order
        end

        it 'displays in JPY' do
          expect(adjustment.display_amount.to_s).to eq '¥11'
        end
      end

      context 'when adjustable is nil' do
        it 'displays in the default currency' do
          expect(adjustment.display_amount.to_s).to eq '$10.55'
        end
      end
    end
  end

  context '#update!' do
    let(:adjustment) { Spree::Adjustment.create!(label: 'Adjustment', order: order, adjustable: order, amount: 5, state: state, source: source) }
    let(:source) { mock_model(Spree::TaxRate, compute_amount: 10) }

    subject { adjustment.update! }

    context "when adjustment is closed" do
      let(:state) { 'closed' }

      it "does not update the adjustment" do
        expect(adjustment).to_not receive(:update_column)
        subject
      end
    end

    context "when adjustment is open" do
      let(:state) { 'open' }

      it "updates the amount" do
        expect { subject }.to change { adjustment.amount }.to(10)
      end

      context "it is a promotion adjustment" do
        let(:promotion) { create(:promotion, :with_order_adjustment, code: promotion_code) }
        let(:promotion_code) { 'somecode' }
        let(:order1) { create(:order_with_line_items, line_items_count: 1) }

        let!(:adjustment) do
          promotion.activate(order: order1, promotion_code: promotion_code)
          expect(order1.adjustments.size).to eq 1
          order1.adjustments.first
        end

        context "the promotion is eligible" do
          it "sets the adjustment elgiible to true" do
            subject
            expect(adjustment.eligible).to eq true
          end
        end

        context "the promotion is not eligible" do
          before { promotion.update!(starts_at: 1.day.from_now) }

          it "sets the adjustment elgiible to false" do
            subject
            expect(adjustment.eligible).to eq false
          end
        end
      end
    end
  end
end
