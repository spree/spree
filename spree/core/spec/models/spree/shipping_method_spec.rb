require 'spec_helper'

class DummyShippingCalculator < Spree::ShippingCalculator
end

describe Spree::ShippingMethod, type: :model do
  let(:shipping_method) { create(:shipping_method) }
  let(:frontend_shipping_method) { create :shipping_method, display_on: 'front_end' }
  let(:backend_shipping_method) { create :shipping_method, display_on: 'back_end' }
  let(:front_and_back_end_shipping_method) { create :shipping_method, display_on: 'both' }

  it_behaves_like 'metadata'

  describe 'scopes' do
    let!(:shipping_methods) { create_list(:shipping_method, 2, display_on: 'both') }
    let!(:frontend_shipping_methods) { create_list(:shipping_method, 2, display_on: 'front_end') }
    let!(:backend_shipping_methods) { create_list(:shipping_method, 2, display_on: 'back_end') }

    describe '.available' do
      subject { described_class.available }

      it { is_expected.to match_array(shipping_methods) }
    end

    describe '.available_on_front_end' do
      subject { described_class.available_on_front_end }

      it { is_expected.to match_array(shipping_methods + frontend_shipping_methods) }
    end

    describe '.available_on_back_end' do
      subject { described_class.available_on_back_end }

      it { is_expected.to match_array(shipping_methods + backend_shipping_methods) }
    end
  end

  describe '#requires_zone_check?' do
    it 'returns true if the shipping method is not digital' do
      expect(shipping_method.requires_zone_check?).to be_truthy
    end

    it 'returns false if the shipping method is digital' do
      shipping_method = create(:digital_shipping_method)
      expect(shipping_method.requires_zone_check?).to be_falsey
    end
  end

  context 'calculators' do
    it "rejects calculators that don't inherit from Spree::ShippingCalculator" do
      allow(Spree::ShippingMethod).to receive_message_chain(:spree_calculators, :shipping_methods).and_return([
                                                                                                                Spree::Calculator::Shipping::FlatPercentItemTotal,
                                                                                                                Spree::Calculator::Shipping::PriceSack,
                                                                                                                Spree::Calculator::DefaultTax,
                                                                                                                DummyShippingCalculator # included as regression test for https://github.com/spree/spree/issues/3109
                                                                                                              ])

      expect(Spree::ShippingMethod.calculators).to eq([Spree::Calculator::Shipping::FlatPercentItemTotal, Spree::Calculator::Shipping::PriceSack, DummyShippingCalculator])
      expect(Spree::ShippingMethod.calculators).not_to eq([Spree::Calculator::DefaultTax])
    end
  end

  # Regression test for #4492
  context '#shipments' do
    let!(:shipping_method) { create(:shipping_method) }
    let!(:shipment) do
      shipment = create(:shipment)
      shipment.shipping_rates.create!(shipping_method: shipping_method)
      shipment
    end

    it 'can gather all the related shipments' do
      expect(shipping_method.shipments).to include(shipment)
    end
  end

  context 'validations' do
    it 'validates presence of name' do
      subject.valid?
      expect(subject.errors.messages[:name].size).to eq(1)
    end

    it 'validates presence of display_on' do
      subject.valid?
      expect(subject.errors.messages[:display_on].size).not_to be_zero
    end

    context 'shipping category' do
      context 'is required' do
        before { subject.valid? }

        it { expect(subject.errors.messages[:base].size).to eq(1) }
        it 'adds error to base' do
          expect(subject.errors.messages[:base]).to include(I18n.t(:required_shipping_category,
                                                            scope: [
                                                              :activerecord, :errors, :models,
                                                              'spree/shipping_method', :attributes, :base
                                                            ]))
        end
      end

      context 'one associated' do
        before { subject.shipping_categories.push(create(:shipping_category)) }

        it { expect(subject.errors.messages[:base]).to be_empty }
      end
    end
  end

  context 'factory' do
    it 'sets calculable correctly' do
      expect(shipping_method.calculator.calculable).to eq(shipping_method)
    end
  end

  describe '#build_tracking_url' do
    context 'shipping method has a tracking URL mask on file' do
      let(:tracking_url) { 'https://track-o-matic.com/:tracking' }

      before { allow(subject).to receive(:tracking_url) { tracking_url } }

      context 'tracking number has spaces' do
        let(:tracking_numbers) { ['1234 5678 9012 3456', 'a bcdef'] }
        let(:expectations) { %w[https://track-o-matic.com/1234%205678%209012%203456 https://track-o-matic.com/A%20BCDEF] }

        it "returns a single URL with '%20' in lieu of spaces" do
          tracking_numbers.each_with_index do |num, i|
            expect(subject.build_tracking_url(num)).to eq(expectations[i])
          end
        end
      end
    end

    context 'shipping method does not have a tracking URL mask on file' do
      let(:usps_tracking_number) { '1Z879E930346834440' }

      before { allow(subject).to receive(:tracking_url) { nil } }

      it 'uses tracking number gem to build tracking url' do
        expect(subject.build_tracking_url(usps_tracking_number)).to eq('https://wwwapps.ups.com/WebTracking/track?track=yes&trackNums=1Z879E930346834440')
      end
    end
  end

  # Regression test for #4320
  context 'soft deletion' do
    let(:shipping_method) { create(:shipping_method) }

    it 'soft-deletes when destroy is called' do
      shipping_method.destroy
      expect(shipping_method.deleted_at).not_to be_blank
    end
  end

  describe '#available_to_display?' do
    context 'when available on frontend' do
      it { expect(frontend_shipping_method.available_to_display?(Spree::ShippingMethod::DISPLAY_ON_FRONT_END)).to be true }
      it { expect(backend_shipping_method.available_to_display?(Spree::ShippingMethod::DISPLAY_ON_FRONT_END)).to be false }
      it { expect(front_and_back_end_shipping_method.available_to_display?(Spree::ShippingMethod::DISPLAY_ON_FRONT_END)).to be true }
    end

    context 'when available on backend' do
      it { expect(frontend_shipping_method.available_to_display?(Spree::ShippingMethod::DISPLAY_ON_BACK_END)).to be false }
      it { expect(backend_shipping_method.available_to_display?(Spree::ShippingMethod::DISPLAY_ON_BACK_END)).to be true }
      it { expect(front_and_back_end_shipping_method.available_to_display?(Spree::ShippingMethod::DISPLAY_ON_BACK_END)).to be true }
    end
  end

  describe '#frontend?' do
    it { expect(frontend_shipping_method.send(:frontend?)).to be true }
    it { expect(backend_shipping_method.send(:frontend?)).to be false }
    it { expect(front_and_back_end_shipping_method.send(:frontend?)).to be true }
  end

  describe '#backend?' do
    it { expect(frontend_shipping_method.send(:backend?)).to be false }
    it { expect(backend_shipping_method.send(:backend?)).to be true }
    it { expect(front_and_back_end_shipping_method.send(:backend?)).to be true }
  end

  describe '#delivery_range' do
    context 'without set estimated_transit_business_days_min and estimated_transit_business_days_max' do
      it { expect(shipping_method.delivery_range).to be_nil }
    end

    context 'with set estimated_transit_business_days_min and estimated_transit_business_days_max' do
      let(:shipping_method) { build(:shipping_method, estimated_transit_business_days_min: 1, estimated_transit_business_days_max: 2) }

      it { expect(shipping_method.delivery_range).to eq('1-2') }
    end

    context 'when both are the same' do
      let(:shipping_method) { build(:shipping_method, estimated_transit_business_days_min: 1, estimated_transit_business_days_max: 1) }

      it { expect(shipping_method.delivery_range).to eq('1') }
    end

    context "when only one transit day value is set" do
      context "when only minimum day is set" do
        let(:shipping_method) { build(:shipping_method, estimated_transit_business_days_min: 1) }

        it { expect(shipping_method.delivery_range).to eq('1') }
      end

      context "when only maximum day is set" do
        let(:shipping_method) { build(:shipping_method, estimated_transit_business_days_max: 2) }

        it { expect(shipping_method.delivery_range).to eq('2') }
      end
    end
  end

  describe '#display_estimated_price' do
    it { expect(shipping_method.display_estimated_price).to eq('Flat rate: $10.00') }

    context 'with the free rate' do
      let(:shipping_method) { build(:free_shipping_method) }

      it { expect(shipping_method.display_estimated_price).to eq('Flat rate: Free') }
    end
  end
end
