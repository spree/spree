require 'spec_helper'

describe Spree::Price, type: :model do
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

  describe '#price' do
    let(:price) { Spree::Price.new }
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

  describe 'validations' do
    subject { Spree::Price.new variant: variant, amount: amount }

    let(:variant) { stub_model Spree::Variant }

    context 'when the amount is nil' do
      let(:amount) { nil }

      it { is_expected.to be_valid }
    end

    context 'when the amount is less than 0' do
      let(:amount) { -1 }

      it 'has 1 error_on' do
        expect(subject.error_on(:amount).size).to eq(1)
      end
      it 'populates errors' do
        subject.valid?
        expect(subject.errors.messages[:amount].first).to eq 'must be greater than or equal to 0'
      end
    end

    context 'when the amount is greater than maximum amount' do
      let(:amount) { Spree::Price::MAXIMUM_AMOUNT + 1 }

      it 'has 1 error_on' do
        expect(subject.error_on(:amount).size).to eq(1)
      end
      it 'populates errors' do
        subject.valid?
        expect(subject.errors.messages[:amount].first).to eq "must be less than or equal to #{Spree::Price::MAXIMUM_AMOUNT}"
      end
    end

    context 'when the amount is between 0 and the maximum amount' do
      let(:amount) { Spree::Price::MAXIMUM_AMOUNT }

      it { is_expected.to be_valid }
    end
  end

  describe '#price_including_vat_for(zone)' do
    let!(:tax_category) { Spree::TaxCategory.create(name: 'FirstCategory', is_default: false) }
    let!(:second_tax_category) { Spree::TaxCategory.create(name: 'SecondCategory', is_default: true) }
    let!(:variant) { create(:variant, tax_category: second_tax_category) }
    let!(:default_zone) { Spree::Zone.create(default_tax: true, name: 'DefaultZone', kind: 'country') }
    let!(:zone) { Spree::Zone.create(default_tax: false, name: 'TestZone', kind: 'country') }
    let!(:country) { Spree::Country.create(name: 'Monaco', iso_name: 'MONACO') }
    let!(:foreign_country) { Spree::Country.create(name: 'Poland', iso_name: 'POLAND') }
    let!(:zone_member) { Spree::ZoneMember.create(zone: default_zone, zoneable: country, zoneable_id: 2) }
    let!(:second_zone_member) { Spree::ZoneMember.create(zone: zone, zoneable: country, zoneable_id: 1) }
    let!(:tax_rate) { create(:tax_rate, zone: zone, included_in_price: true, tax_category: second_tax_category, amount: 0.05) }
    let(:amount) { 10 }
    let(:price) { Spree::Price.new variant: variant, amount: amount }
    let(:price_options) { { tax_zone: zone } }

    context 'when called with a non-default zone' do
      it 'returns the correct price including another VAT to two digits' do
        expect(price_with_vat).to eq(10.50)
      end
    end

    context 'when called from the default zone' do
      before do
        allow(variant).to receive(:tax_category).and_return(tax_category)
      end

      it 'returns the correct price' do
        expect(price_with_vat).to eq(10.00)
      end
    end

    context 'when no default zone is set' do
      before do
        allow(variant).to receive(:tax_category).and_return(tax_category)
      end

      it 'returns the correct price' do
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
end
