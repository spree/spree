require 'spec_helper'

describe Spree::PriceList, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:price_rules).dependent(:destroy) }
    it { is_expected.to have_many(:prices).dependent(:nullify) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:priority) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:match_policy) }
    it { is_expected.to validate_inclusion_of(:status).in_array(%w[active inactive scheduled]) }
    it { is_expected.to validate_inclusion_of(:match_policy).in_array(%w[all any]) }

    context 'date range validation' do
      let(:price_list) { build(:price_list, starts_at: 2.days.from_now, ends_at: 1.day.from_now) }

      it 'validates starts_at is before ends_at' do
        expect(price_list).not_to be_valid
        expect(price_list.errors[:ends_at]).to include('must be after starts at')
      end
    end
  end

  describe 'scopes' do
    let!(:active_price_list) { create(:price_list, status: 'active') }
    let!(:inactive_price_list) { create(:price_list, status: 'inactive') }
    let!(:scheduled_price_list) { create(:price_list, status: 'scheduled') }
    let!(:high_priority_list) { create(:price_list, priority: 100) }
    let!(:low_priority_list) { create(:price_list, priority: 10) }

    describe '.active' do
      it 'returns only active price lists' do
        expect(described_class.active).to include(active_price_list)
        expect(described_class.active).not_to include(inactive_price_list)
      end
    end

    describe '.inactive' do
      it 'returns only inactive price lists' do
        expect(described_class.inactive).to include(inactive_price_list)
        expect(described_class.inactive).not_to include(active_price_list)
      end
    end

    describe '.scheduled' do
      it 'returns only scheduled price lists' do
        expect(described_class.scheduled).to include(scheduled_price_list)
        expect(described_class.scheduled).not_to include(active_price_list)
      end
    end

    describe '.by_priority' do
      it 'returns price lists ordered by priority descending' do
        ordered = described_class.by_priority.to_a
        high_index = ordered.index(high_priority_list)
        low_index = ordered.index(low_priority_list)
        expect(high_index).to be < low_index
      end
    end

    describe '.current' do
      let!(:past_list) { create(:price_list, ends_at: 1.day.ago) }
      let!(:future_list) { create(:price_list, starts_at: 1.day.from_now) }
      let!(:current_list) { create(:price_list, starts_at: 1.day.ago, ends_at: 1.day.from_now) }

      it 'returns only price lists within date range' do
        expect(described_class.current).to include(current_list)
        expect(described_class.current).not_to include(past_list, future_list)
      end
    end
  end

  describe '#applicable?' do
    let(:price_list) { create(:price_list, status: 'active') }
    let(:variant) { create(:variant) }
    let(:context) { Spree::Pricing::Context.new(variant: variant, currency: 'USD') }

    context 'when price list is inactive' do
      before { price_list.update(status: 'inactive') }

      it 'returns false' do
        expect(price_list.applicable?(context)).to be false
      end
    end

    context 'when price list is outside date range' do
      before { price_list.update(starts_at: 1.week.from_now, ends_at: 2.weeks.from_now) }

      it 'returns false' do
        expect(price_list.applicable?(context)).to be false
      end
    end

    context 'with rules and match_policy = all' do
      let!(:passing_rule) do
        rule = create(:store_price_rule, price_list: price_list)
        allow(rule).to receive(:applicable?).and_return(true)
        rule
      end
      let!(:failing_rule) do
        rule = create(:zone_price_rule, price_list: price_list)
        allow(rule).to receive(:applicable?).and_return(false)
        rule
      end

      before { price_list.update(match_policy: 'all') }

      it 'returns false if any rule fails' do
        expect(price_list.applicable?(context)).to be false
      end
    end

    context 'with rules and match_policy = any' do
      let!(:passing_rule) do
        rule = create(:store_price_rule, price_list: price_list)
        allow(rule).to receive(:applicable?).and_return(true)
        rule
      end
      let!(:failing_rule) do
        rule = create(:zone_price_rule, price_list: price_list)
        allow(rule).to receive(:applicable?).and_return(false)
        rule
      end

      before { price_list.update(match_policy: 'any') }

      it 'returns true if any rule passes' do
        expect(price_list.applicable?(context)).to be true
      end
    end
  end

  describe '#active?' do
    it 'returns true when status is active' do
      price_list = build(:price_list, status: 'active')
      expect(price_list.active?).to be true
    end

    it 'returns false when status is not active' do
      price_list = build(:price_list, status: 'inactive')
      expect(price_list.active?).to be false
    end
  end
end
