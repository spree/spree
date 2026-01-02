require 'spec_helper'

describe Spree::PriceList, type: :model do
  describe 'Validations' do
    context 'date range validation' do
      let(:price_list) { build(:price_list, starts_at: 2.days.from_now, ends_at: 1.day.from_now) }

      it 'validates starts_at is before ends_at' do
        expect(price_list).not_to be_valid
        expect(price_list.errors[:ends_at]).to include('must be after starts at')
      end
    end
  end

  describe 'state_machine' do
    let(:price_list) { create(:price_list) }

    it 'has initial status of inactive' do
      expect(price_list.status).to eq('inactive')
    end

    describe '#activate' do
      it 'transitions to active' do
        price_list.activate
        expect(price_list.status).to eq('active')
      end
    end

    describe '#deactivate' do
      before { price_list.activate }

      it 'transitions to inactive' do
        price_list.deactivate
        expect(price_list.status).to eq('inactive')
      end
    end

    describe '#schedule' do
      it 'transitions to scheduled' do
        price_list.schedule
        expect(price_list.status).to eq('scheduled')
      end
    end
  end

  describe 'scopes' do
    let(:store) { create(:store) }
    let!(:active_price_list) { create(:price_list, :active, store: store) }
    let!(:inactive_price_list) { create(:price_list, store: store) }
    let!(:scheduled_price_list) { create(:price_list, :scheduled, store: store) }

    describe '.with_status(:active)' do
      it 'returns only active price lists' do
        expect(described_class.with_status(:active)).to include(active_price_list)
        expect(described_class.with_status(:active)).not_to include(inactive_price_list)
      end
    end

    describe '.with_status(:inactive)' do
      it 'returns only inactive price lists' do
        expect(described_class.with_status(:inactive)).to include(inactive_price_list)
        expect(described_class.with_status(:inactive)).not_to include(active_price_list)
      end
    end

    describe '.with_status(:scheduled)' do
      it 'returns only scheduled price lists' do
        expect(described_class.with_status(:scheduled)).to include(scheduled_price_list)
        expect(described_class.with_status(:scheduled)).not_to include(active_price_list)
      end
    end

    describe '.by_position' do
      let!(:first_list) { create(:price_list, store: store, position: 1) }
      let!(:second_list) { create(:price_list, store: store, position: 2) }

      it 'returns price lists ordered by position ascending' do
        ordered = described_class.by_position.where(store: store).to_a
        first_index = ordered.index(first_list)
        second_index = ordered.index(second_list)
        expect(first_index).to be < second_index
      end
    end

    describe '.for_store' do
      let(:other_store) { create(:store) }
      let!(:other_store_list) { create(:price_list, store: other_store) }

      it 'returns only price lists for the specified store' do
        expect(described_class.for_store(store)).to include(active_price_list)
        expect(described_class.for_store(store)).not_to include(other_store_list)
      end
    end

    describe '.current' do
      let!(:past_list) { create(:price_list, store: store, ends_at: 1.day.ago) }
      let!(:future_list) { create(:price_list, store: store, starts_at: 1.day.from_now) }
      let!(:current_list) { create(:price_list, store: store, starts_at: 1.day.ago, ends_at: 1.day.from_now) }

      it 'returns only price lists within date range' do
        expect(described_class.current).to include(current_list)
        expect(described_class.current).not_to include(past_list, future_list)
      end

      it 'accepts a timezone parameter' do
        expect(described_class.current('America/New_York')).to include(current_list)
      end
    end
  end

  describe '#applicable?' do
    let(:store) { create(:store) }
    let(:price_list) { create(:price_list, :active, store: store) }
    let(:variant) { create(:variant) }
    let(:context) { Spree::Pricing::Context.new(variant: variant, currency: 'USD', store: store) }

    context 'when price list is inactive' do
      before { price_list.deactivate }

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
      let!(:passing_rule) { create(:zone_price_rule, price_list: price_list) }
      let!(:failing_rule) { create(:user_price_rule, price_list: price_list) }

      before do
        price_list.update(match_policy: 'all')
        price_list.price_rules.reload
        allow(price_list.price_rules.first).to receive(:applicable?).and_return(true)
        allow(price_list.price_rules.second).to receive(:applicable?).and_return(false)
      end

      it 'returns false if any rule fails' do
        expect(price_list.applicable?(context)).to be false
      end
    end

    context 'with rules and match_policy = any' do
      let!(:passing_rule) { create(:zone_price_rule, price_list: price_list) }
      let!(:failing_rule) { create(:user_price_rule, price_list: price_list) }

      before do
        price_list.update(match_policy: 'any')
        price_list.price_rules.reload
        allow(price_list.price_rules.first).to receive(:applicable?).and_return(true)
        allow(price_list.price_rules.second).to receive(:applicable?).and_return(false)
      end

      it 'returns true if any rule passes' do
        expect(price_list.applicable?(context)).to be true
      end
    end
  end

  describe '#active?' do
    it 'returns true when status is active' do
      price_list = create(:price_list, :active)
      expect(price_list.active?).to be true
    end

    it 'returns false when status is not active' do
      price_list = create(:price_list)
      expect(price_list.active?).to be false
    end
  end

  describe '#add_products' do
    let(:store) { create(:store, supported_currencies: 'USD,EUR,GBP') }
    let(:price_list) { create(:price_list, store: store) }
    let(:product1) { create(:product, stores: [store]) }
    let(:product2) { create(:product, stores: [store]) }

    it 'creates prices for all variants of the given products' do
      expect {
        price_list.add_products([product1.id, product2.id])
      }.to change { price_list.prices.count }.by(6) # 2 products * 3 currencies
    end

    it 'creates prices for all supported currencies' do
      price_list.add_products([product1.id])

      currencies = price_list.prices.where(variant_id: product1.master.id).pluck(:currency)
      expect(currencies).to match_array(%w[USD EUR GBP])
    end

    it 'creates prices with nil amount' do
      price_list.add_products([product1.id])

      expect(price_list.prices.pluck(:amount).uniq).to eq([nil])
    end

    it 'does not create duplicate prices for existing variants' do
      price_list.prices.create!(variant: product1.master, currency: 'USD', amount: nil)

      expect {
        price_list.add_products([product1.id])
      }.to change { price_list.prices.count }.by(2) # Only EUR and GBP, not USD
    end

    it 'handles empty product_ids' do
      expect {
        price_list.add_products([])
      }.not_to change { price_list.prices.count }
    end

    it 'handles nil product_ids' do
      expect {
        price_list.add_products(nil)
      }.not_to change { price_list.prices.count }
    end

    context 'with products having multiple variants' do
      let(:product_with_variants) { create(:product, stores: [store]) }
      let!(:variant1) { create(:variant, product: product_with_variants) }
      let!(:variant2) { create(:variant, product: product_with_variants) }

      it 'creates prices for all eligible variants' do
        eligible_count = Spree::Variant.eligible.where(product_id: product_with_variants.id).count

        expect {
          price_list.add_products([product_with_variants.id])
        }.to change { price_list.prices.count }.by(eligible_count * 3) # variants * 3 currencies
      end
    end
  end

  describe '#remove_products' do
    let(:store) { create(:store, supported_currencies: 'USD,EUR,GBP') }
    let(:price_list) { create(:price_list, store: store) }
    let(:product1) { create(:product, stores: [store]) }
    let(:product2) { create(:product, stores: [store]) }

    before do
      price_list.add_products([product1.id, product2.id])
    end

    it 'removes all prices for the given products' do
      expect {
        price_list.remove_products([product1.id])
      }.to change { price_list.prices.count }.by(-3) # 1 product * 3 currencies
    end

    it 'removes prices for all currencies' do
      price_list.remove_products([product1.id])

      expect(price_list.prices.joins(:variant).where(spree_variants: { product_id: product1.id }).count).to eq(0)
    end

    it 'does not remove prices for other products' do
      price_list.remove_products([product1.id])

      expect(price_list.prices.joins(:variant).where(spree_variants: { product_id: product2.id }).count).to eq(3)
    end

    it 'handles empty product_ids' do
      expect {
        price_list.remove_products([])
      }.not_to change { price_list.prices.count }
    end

    it 'handles nil product_ids' do
      expect {
        price_list.remove_products(nil)
      }.not_to change { price_list.prices.count }
    end

    it 'removes prices for multiple products at once' do
      expect {
        price_list.remove_products([product1.id, product2.id])
      }.to change { price_list.prices.count }.by(-6) # 2 products * 3 currencies
    end
  end
end
