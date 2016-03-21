require 'spec_helper'

describe Spree::Price, :type => :model do

  it_behaves_like 'a Paranoid model'

  describe 'Modules' do
    describe 'Inclusions' do
      it { expect(Spree::Price.include?(Spree::VatPriceCalculation)).to be true }
      it { expect(Spree::Price.ancestors).to include Spree::DisplayMoney }
    end
  end

  describe 'Constants' do
    describe 'AMOUNT_LIMIT[:max]' do
      it 'return 99999999.99' do
        expect(Spree::Price::AMOUNT_LIMIT[:max]).to eq BigDecimal('99_999_999.99')
      end
    end

    describe 'AMOUNT_LIMIT[:min]' do
      it 'return 0' do
        expect(Spree::Price::AMOUNT_LIMIT[:min]).to eq 0
      end
    end
  end

  describe 'association' do
    it do
      is_expected.to belong_to(:variant).class_name('Spree::Variant').
        inverse_of(:prices).touch(true)
    end
  end

  describe 'validations' do
    let(:variant) { stub_model Spree::Variant }
    subject { Spree::Price.new variant: variant, amount: amount }

    context 'when the amount is nil' do
      let(:amount) { nil }
      it { is_expected.to be_valid }
    end

    context 'when the amount is less than #{Spree::Price::AMOUNT_LIMIT[:min]}' do
      let(:amount) { -1 }

      it 'has 1 error_on' do
        expect(subject.error_on(:amount).size).to eq(1)
      end
      it 'populates errors' do
        subject.valid?
        expect(subject.errors.messages[:amount].first).
          to eq "must be greater than or equal to #{Spree::Price::AMOUNT_LIMIT[:min]}"
      end
    end

    context 'when the amount is greater than maximum amount' do
      let(:amount) { Spree::Price::AMOUNT_LIMIT[:max] + 1 }

      it 'has 1 error_on' do
        expect(subject.error_on(:amount).size).to eq(1)
      end
      it 'populates errors' do
        subject.valid?
        expect(subject.errors.messages[:amount].first).
          to eq "must be less than or equal to #{Spree::Price::AMOUNT_LIMIT[:max]}"
      end
    end

    context 'when the amount is between 0 and the maximum amount' do
      let(:amount) { Spree::Price::AMOUNT_LIMIT[:max] }
      it { is_expected.to be_valid }
    end
  end

  describe 'Callbacks' do
    it { is_expected.to callback(:ensure_currency).before(:validation) }
  end

  describe 'whitelisted ransackable attributes' do
    it 'returns amount attribute' do
      expect(Spree::Price.whitelisted_ransackable_attributes).to eq(['amount'])
    end
  end

  # Instance methods

  describe 'Instance Methods' do
    describe '#amount=' do
      let(:price) { Spree::Price.new }
      let(:amount) { '3,0A0' }

      before do
        price.amount = amount
      end

      it 'is expected to equal to localized number' do
        expect(price.amount).to eq(Spree::LocalizedNumber.parse(amount))
      end
    end

    describe '#price_including_vat_for(zone)' do
      let(:variant) { stub_model Spree::Variant }
      let(:default_zone) { Spree::Zone.new }
      let(:zone) { Spree::Zone.new }
      let(:amount) { 10 }
      let(:tax_category) { Spree::TaxCategory.new }
      let(:price) { Spree::Price.new variant: variant, amount: amount }
      let(:price_options) { { tax_zone: zone } }

      subject(:price_with_vat) { price.price_including_vat_for(price_options) }

      context 'when called with a non-default zone' do
        before do
          allow(variant).to receive(:tax_category).and_return(tax_category)
          expect(price).to receive(:default_zone).at_least(:once).and_return(default_zone)
          allow(price).to receive(:apply_foreign_vat?).and_return(true)
          allow(price).to receive(:included_tax_amount).
            with(tax_zone: default_zone, tax_category: tax_category) { 0.19 }
          allow(price).to receive(:included_tax_amount).with(tax_zone: zone, tax_category: tax_category) { 0.25 }
        end

        it "returns the correct price including another VAT to two digits" do
          expect(price_with_vat).to eq(10.50)
        end
      end

      context 'when called from the default zone' do
        before do
          allow(variant).to receive(:tax_category).and_return(tax_category)
          expect(price).to receive(:default_zone).at_least(:once).and_return(zone)
        end

        it "returns the correct price" do
          expect(price).to receive(:price).and_call_original
          expect(price_with_vat).to eq(10.00)
        end
      end

      context 'when no default zone is set' do
        before do
          allow(variant).to receive(:tax_category).and_return(tax_category)
          expect(price).to receive(:default_zone).at_least(:once).and_return(nil)
        end

        it "returns the correct price" do
          expect(price).to receive(:price).and_call_original
          expect(price.price_including_vat_for(tax_zone: zone)).to eq(10.00)
        end
      end
    end

    describe '#display_price_including_vat_for(zone)' do
      subject { Spree::Price.new amount: 10 }
      it 'calls #price_including_vat_for' do
        expect(subject).to receive(:price_including_vat_for)
        subject.display_price_including_vat_for(nil)
      end
    end

    describe '#money' do
      context 'when price has amount' do
        let(:price) { build(:price) }
        it 'reutrns amount with currency' do
          expect(price.money.to_s).to eq('$19.99')
        end
      end

      context 'when price does not has amount' do
        let(:price) { build(:price) }
        before { price.amount = nil }
        it 'reutrns amount with currency' do
          expect(price.money.to_s).to eq('$0.00')
        end
      end
    end

    describe '#price' do
      let(:price) { build(:price) }
      it 'returns amount' do
        expect(price.price).to eq(price.amount)
      end
    end

    describe '#price=' do
      let(:price) { build(:price) }
      context 'when price contains currency symbol' do
        it 'removes currency symbol' do
          expect(Spree::LocalizedNumber).to receive(:parse).with(price.price)
          price.price = 19.99
        end
      end
    end

    describe '#variant' do
      let(:price) { create(:price) }
      subject(:variant) { price.variant }
      before do
        variant.deleted_at = Time.current
        variant.save
      end
      it 'returns variants without adding the deleted_at where clause when unscoped' do
        expect(price.reload.variant).to eq variant
      end
    end

    describe '#ensure_currency' do
      let(:price) { create(:price) }

      context 'when currency is not already set' do
        it 'sets currency to Spree::Config[:currency]' do
          expect(price.currency).to eq Spree::Config[:currency]
        end
      end

      context 'when currency is already set and configuration changes' do
        subject(:currency) { 'RS' }
        before do
          Spree::Config[:currency] = currency
          price.save
        end
        it 'does not sets currency to Spree::Config[:currency]' do
          expect(price.currency).not_to eq currency
        end
      end
    end
  end
end
