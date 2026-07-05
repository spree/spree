require 'spec_helper'

describe Spree::Price, type: :model do
  it_behaves_like 'lifecycle events', factory: :price_eur

  describe 'Callbacks' do
    context 'when compare_at_amount is equal to amount' do
      let(:variant) { create(:variant) }

      let(:price) do
        build(
          :price,
          amount: 10,
          compare_at_amount: 10,
          currency: 'GBP',
          variant: variant
        )
      end

      it 'sets compare_at_amount to nil' do
        price.save
        expect(price.compare_at_amount).to be_nil
      end
    end

    describe 'after_commit :auto_match_taxons' do
      context 'when price is discounted' do
        context 'on create' do
          let(:price) { build(:price, amount: 10, compare_at_amount: 20, currency: 'GBP') }

          it 'auto matches taxons' do
            expect_any_instance_of(Spree::Product).to receive(:auto_match_taxons).at_least(:once)
            price.save
          end
        end

        context 'on update' do
          let!(:price) { create(:price, amount: 10, compare_at_amount: 20, currency: 'GBP') }

          context 'and changed to not be discounted' do
            it 'auto matches taxons' do
              expect_any_instance_of(Spree::Product).to receive(:auto_match_taxons)
              price.reload.update(compare_at_amount: nil)
            end
          end

          context 'and is still discounted' do
            it 'does not touch shop product' do
              expect_any_instance_of(Spree::Product).not_to receive(:auto_match_taxons)
              price.reload.update(amount: 15)
            end
          end
        end
      end

      context 'when price is not discounted' do
        let(:price) { build(:price, amount: 10, compare_at_amount: nil, currency: 'GBP') }

        context 'on create' do
          it 'auto matches taxons' do
            expect_any_instance_of(Spree::Product).to receive(:auto_match_taxons)
            price.save
          end
        end

        context 'on update' do
          let!(:price) { create(:price, amount: 10, compare_at_amount: nil, currency: 'GBP') }

          context 'and changed to be discounted' do
            it 'auto matches taxons' do
              expect_any_instance_of(Spree::Product).to receive(:auto_match_taxons)
              price.reload.update(compare_at_amount: 20)
            end
          end

          context 'and is still not discounted' do
            it 'does not touch shop product' do
              expect_any_instance_of(Spree::Product).not_to receive(:auto_match_taxons)
              price.reload.update(amount: 15)
            end
          end
        end
      end
    end
  end

  describe '#amount=' do
    let(:price) { build :price }
    let(:amount) { '3,0A0' }

    before do
      price.amount = amount
    end

    it 'is expected to equal to localized number' do
      expect(price.amount).to eq(Spree::LocalizedNumber.parse(amount))
    end
  end

  describe '#compare_at_amount=' do
    let(:price) { build(:price) }
    let(:compare_at_amount) { '169.99' }

    before do
      price.compare_at_amount = compare_at_amount
    end

    it 'is expected to equal to localized number' do
      expect(price.compare_at_amount).to eq(Spree::LocalizedNumber.parse(compare_at_amount))
    end

    context 'with empty string being passed as value' do
      let(:compare_at_amount) { '' }

      it 'casts value to nil' do
        expect(price.compare_at_amount).to be_nil
      end
    end
  end

  describe '#price' do
    let(:price) { build :price }
    let(:amount) { 3000.00 }

    context 'when amount is changed' do
      before do
        price.amount = amount
      end

      it 'is expected to equal to price' do
        expect(price.amount).to eq(price.price)
      end
    end
  end

  describe '#compare_at_price' do
    let(:price) { build :price }
    let(:compare_at_amount) { 3000.00 }

    context 'when amount is changed' do
      before do
        price.compare_at_amount = compare_at_amount
      end

      it 'is expected to equal to price' do
        expect(price.compare_at_amount).to eq(price.compare_at_price)
      end
    end
  end

  describe 'validations' do
    subject { build :price, variant: variant, amount: amount }

    let(:variant) { create(:variant) }

    context 'when the amount is nil' do
      let(:amount) { nil }

      context 'legacy behavior' do
        before do
          allow(Spree::Config).to receive(:allow_empty_price_amount).and_return(true)
        end

        it { is_expected.to be_valid }
      end

      context 'new behavior' do
        it { is_expected.not_to be_valid }
      end
    end

    context 'when the amount is less than 0' do
      let(:amount) { -1 }
      before { subject.valid? }

      it 'has 1 error on amount' do
        expect(subject.errors.messages[:amount].size).to eq(1)
      end
      it 'populates errors' do
        expect(subject.errors.messages[:amount].first).to eq 'must be greater than or equal to 0'
      end
    end

    context 'when the amount is greater than maximum amount' do
      let(:amount) { Spree::Price::MAXIMUM_AMOUNT + 1 }
      before { subject.valid? }

      it 'has 1 error on amount' do
        expect(subject.errors.messages[:amount].size).to eq(1)
      end
      it 'populates errors' do
        expect(subject.errors.messages[:amount].first).to eq "must be less than or equal to #{Spree::Price::MAXIMUM_AMOUNT}"
      end
    end

    context 'when the amount is between 0 and the maximum amount' do
      let(:amount) { Spree::Price::MAXIMUM_AMOUNT }

      it { is_expected.to be_valid }
    end
  end

  describe '#price_including_vat_for(zone)' do
    subject(:price_with_vat) { price.price_including_vat_for(price_options) }

    let(:variant) { create(:variant) }
    let(:default_zone) { Spree::Zone.new }
    let(:zone) { Spree::Zone.new }
    let(:amount) { 10 }
    let(:tax_category) { Spree::TaxCategory.new }
    let(:price) { build :price, variant: variant, amount: amount }
    let(:price_options) { { tax_zone: zone } }

    context 'when called with a non-default zone' do
      before do
        allow(variant).to receive(:tax_category).and_return(tax_category)
        expect(price).to receive(:default_zone).at_least(:once).and_return(default_zone)
        allow(price).to receive(:apply_foreign_vat?).and_return(true)
        allow(price).to receive(:included_tax_amount).with({ tax_zone: default_zone, tax_category: tax_category }).and_return(0.19)
        allow(price).to receive(:included_tax_amount).with({ tax_zone: zone, tax_category: tax_category }).and_return(0.25)
      end

      it 'returns the correct price including another VAT to two digits' do
        expect(price_with_vat).to eq(10.50)
      end
    end

    context 'when called from the default zone' do
      before do
        allow(variant).to receive(:tax_category).and_return(tax_category)
        expect(price).to receive(:default_zone).at_least(:once).and_return(zone)
      end

      it 'returns the correct price' do
        expect(price).to receive(:price).and_call_original
        expect(price_with_vat).to eq(10.00)
      end
    end

    context 'when no default zone is set' do
      before do
        allow(variant).to receive(:tax_category).and_return(tax_category)
        expect(price).to receive(:default_zone).at_least(:once).and_return(nil)
      end

      it 'returns the correct price' do
        expect(price).to receive(:price).and_call_original
        expect(price.price_including_vat_for(tax_zone: zone)).to eq(10.00)
      end
    end
  end

  describe '#compare_at_price_including_vat_for(zone)' do
    subject(:compare_at_price_with_vat) { price.compare_at_price_including_vat_for(price_options) }

    let(:variant) { create(:variant) }
    let(:default_zone) { Spree::Zone.new }
    let(:zone) { Spree::Zone.new }
    let(:amount) { 10 }
    let(:compare_at_amount) { 100 }
    let(:tax_category) { Spree::TaxCategory.new }
    let(:price) { build :price, variant: variant, amount: amount, compare_at_amount: compare_at_amount }
    let(:price_options) { { tax_zone: zone } }

    context 'when called with a non-default zone' do
      before do
        allow(variant).to receive(:tax_category).and_return(tax_category)
        expect(price).to receive(:default_zone).at_least(:once).and_return(default_zone)
        allow(price).to receive(:apply_foreign_vat?).and_return(true)
        allow(price).to receive(:included_tax_amount).with({ tax_zone: default_zone, tax_category: tax_category }).and_return(0.19)
        allow(price).to receive(:included_tax_amount).with({ tax_zone: zone, tax_category: tax_category }).and_return(0.25)
      end

      it 'returns the correct price including another VAT to two digits' do
        expect(compare_at_price_with_vat).to eq(105.04)
      end
    end

    context 'when called from the default zone' do
      before do
        allow(variant).to receive(:tax_category).and_return(tax_category)
        expect(price).to receive(:default_zone).at_least(:once).and_return(zone)
      end

      it 'returns the correct price' do
        expect(price).to receive(:compare_at_price).and_call_original
        expect(compare_at_price_with_vat).to eq(100.00)
      end
    end

    context 'when no default zone is set' do
      before do
        allow(variant).to receive(:tax_category).and_return(tax_category)
        expect(price).to receive(:default_zone).at_least(:once).and_return(nil)
      end

      it 'returns the correct price' do
        expect(price).to receive(:compare_at_price).and_call_original
        expect(price.compare_at_price_including_vat_for(tax_zone: zone)).to eq(100.00)
      end
    end
  end

  describe '#display_price_including_vat_for(zone)' do
    subject { build :price, amount: 10 }

    it 'calls #price_including_vat_for' do
      expect(subject).to receive(:price_including_vat_for)
      subject.display_price_including_vat_for(nil)
    end
  end

  describe '#display_compare_at_price_including_vat_for(zone)' do
    subject { build :price, amount: 10, compare_at_amount: 100 }

    it 'calls #price_including_vat_for' do
      expect(subject).to receive(:compare_at_price_including_vat_for)
      subject.display_compare_at_price_including_vat_for(nil)
    end
  end

  describe '#display_compare_at_amount' do
    let(:price) { build(:price, amount: 10, compare_at_amount: compare_at_amount, currency: 'USD') }

    context 'when compare_at_amount is set' do
      let(:compare_at_amount) { 19.99 }

      it 'returns a Spree::Money object' do
        expect(price.display_compare_at_amount).to be_a(Spree::Money)
        expect(price.display_compare_at_amount.to_s).to eq('$19.99')
      end
    end

    context 'when compare_at_amount is nil' do
      let(:compare_at_amount) { nil }

      it 'returns nil' do
        expect(price.display_compare_at_amount).to be_nil
      end
    end
  end

  describe '#compare_at_amount_in_cents' do
    let(:price) { build(:price, amount: 10, compare_at_amount: compare_at_amount, currency: 'USD') }

    context 'when compare_at_amount is set' do
      let(:compare_at_amount) { 19.99 }

      it 'returns the amount in cents' do
        expect(price.compare_at_amount_in_cents).to eq(1999)
      end
    end

    context 'when compare_at_amount is nil' do
      let(:compare_at_amount) { nil }

      it 'returns nil' do
        expect(price.compare_at_amount_in_cents).to be_nil
      end
    end
  end

  describe '#discounted?' do
    subject { price.discounted? }

    let(:price) { build(:price, amount: 10, compare_at_amount: compare_at_amount, currency: 'USD') }

    context 'when compare at amount is higher' do
      let(:compare_at_amount) { 15 }
      it { is_expected.to be(true) }
    end

    context 'when compare at amount is lower' do
      let(:compare_at_amount) { 9 }
      it { is_expected.to be(false) }
    end

    context 'when compare at amount is the same' do
      let(:compare_at_amount) { 10 }
      it { is_expected.to be(false) }
    end

    context 'when there is no compare at amount' do
      let(:compare_at_amount) { nil }
      it { is_expected.to be(false) }
    end
  end

  describe '#record_price_history' do
    let(:store) { create(:store) }
    let(:variant) { create(:variant) }
    let(:price) { variant.default_price }

    before do
      # Materialize lets and clear history from setup
      price
      Spree::PriceHistory.delete_all
    end

    context 'when amount changes on a base price' do
      it 'creates a price history record' do
        expect {
          price.update!(amount: 29.99)
        }.to change { price.price_histories.count }.by(1)

        history = price.price_histories.last
        expect(history.variant).to eq(variant)
        expect(history.amount).to eq(29.99)
        expect(history.currency).to eq(price.currency)
        expect(history.recorded_at).to be_present
      end
    end

    context 'when only compare_at_amount changes' do
      it 'does not create a price history record' do
        expect {
          price.update!(compare_at_amount: 39.99)
        }.not_to change { price.price_histories.count }
      end
    end

    context 'when price belongs to a price list' do
      let(:price_list) { create(:price_list, store: store) }

      it 'does not create a price history record' do
        list_price = create(:price, variant: variant, price_list: price_list, amount: 10.0, currency: 'USD')

        expect {
          list_price.update!(amount: 15.0)
        }.not_to change { list_price.price_histories.count }
      end
    end

    context 'when track_price_history is disabled' do
      before do
        Spree::Config[:track_price_history] = false
      end

      after do
        Spree::Config[:track_price_history] = true
      end

      it 'does not create a price history record' do
        expect {
          price.update!(amount: 29.99)
        }.not_to change { price.price_histories.count }
      end
    end

    context 'when creating a new base price' do
      it 'creates a price history record' do
        new_price = create(:price, variant: variant, amount: 25.0, currency: 'EUR')

        expect(new_price.price_histories.count).to eq(1)
        expect(new_price.price_histories.first.amount).to eq(25.0)
      end
    end
  end

  describe '#prior_price' do
    let(:variant) { create(:variant) }
    let(:price) { variant.default_price }

    before do
      price
      price.price_histories.delete_all
    end

    context 'with price history' do
      before do
        create(:price_history, price: price, variant: variant, amount: 15.0, currency: price.currency, recorded_at: 5.days.ago)
        create(:price_history, price: price, variant: variant, amount: 10.0, currency: price.currency, recorded_at: 20.days.ago)
        create(:price_history, price: price, variant: variant, amount: 5.0, currency: price.currency, recorded_at: 45.days.ago)
      end

      it 'returns the price history record with the lowest amount within 30 days' do
        result = price.prior_price
        expect(result).to be_a(Spree::PriceHistory)
        expect(result.amount).to eq(10.0)
        expect(result.currency).to eq(price.currency)
      end
    end

    context 'without price history' do
      it 'returns nil' do
        expect(price.prior_price).to be_nil
      end
    end
  end
end
