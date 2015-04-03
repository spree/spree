require 'spec_helper'

describe Spree::Price, :type => :model do
  describe 'validations' do
    let(:variant) { stub_model Spree::Variant }
    subject { Spree::Price.new variant: variant, amount: amount }

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

    context 'when the amount is greater than 999,999.99' do
      let(:amount) { 1_000_000 }

      it 'has 1 error_on' do
        expect(subject.error_on(:amount).size).to eq(1)
      end
      it 'populates errors' do
        subject.valid?
        expect(subject.errors.messages[:amount].first).to eq 'must be less than or equal to 999999.99'
      end
    end

    context 'when the amount is between 0 and 999,999.99' do
      let(:amount) { 100 }
      it { is_expected.to be_valid }
    end
  end

  # For correct VAT calculation, we have to be able to save prices to six digits.
  describe 'precision' do
    let(:amount) { "7.94356" }
    let(:variant) { create(:variant) }
    before do
      @price = subject
      @price.amount = amount
      @price.variant_id = variant.id
      @price.save
    end

    it 'retains high precision input' do
      expect(@price.reload.amount).to eq(BigDecimal.new(amount))
    end
  end

  # Used to display a price including the correct VAT
  # for a particular order.
  describe "#display_price_adding_vat_for(order)" do
    let(:amount) { "10.0" }
    let(:variant) { create(:variant) }
    let(:current_order) {Spree::Order.new}
    let(:price) { Spree::Price.new variant: variant, amount: amount }
    let(:zone) { create(:zone_with_country) }
    let(:vat) do
      create(
        :tax_rate,
        included_in_price: true,
        zone: zone,
        tax_category: variant.tax_category,
        amount: 0.2
      )
    end
    let(:default_zone) { create(:zone_with_country, default_tax: true) }
    let(:default_vat) do
      create(
        :tax_rate,
        included_in_price: true,
        zone: default_zone,
        tax_category: variant.tax_category,
        amount: 0.3
      )
    end

    subject { price.display_price_adding_vat_for(current_order) }

    context "with no default VAT" do
      context "with no specific order tax zone" do
        it "displays the price without vat" do
          expect(subject).to eq(Spree::Money.new(10))
        end
      end

      context "with a VAT in the orders zone" do
        before do
          expect(current_order).to receive(:tax_zone).and_return(zone)
          vat
        end

        it "displays the price including vat" do
          expect(subject).to eq(Spree::Money.new(12))
        end
      end
    end

    context "with a default VAT" do
      before do
        default_vat
      end

      context "with no specific order tax zone" do
        it "displays the price without vat" do
          expect(subject).to eq(Spree::Money.new(13))
        end
      end

      context "with a VAT in the orders zone" do
        before do
          expect(current_order).to receive(:tax_zone).and_return(zone)
          vat
        end

        it "displays the price including vat" do
          expect(subject).to eq(Spree::Money.new(12))
        end
      end
    end
  end
end
