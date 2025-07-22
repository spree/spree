require 'spec_helper'

describe Spree::Price, type: :model do
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
    let(:price) { build :price }
    let(:compare_at_amount) { '169.99' }

    before do
      price.compare_at_amount = compare_at_amount
    end

    it 'is expected to equal to localized number' do
      expect(price.compare_at_amount).to eq(Spree::LocalizedNumber.parse(compare_at_amount))
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
end
