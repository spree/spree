require 'spec_helper'

class DummyShippingCalculator < Spree::ShippingCalculator
end

describe Spree::DeliveryMethod, type: :model do
  let(:delivery_method) { create(:delivery_method) }
  let(:frontend_delivery_method) { create :delivery_method, display_on: 'front_end' }
  let(:backend_delivery_method) { create :delivery_method, display_on: 'back_end' }
  let(:front_and_back_end_delivery_method) { create :delivery_method, display_on: 'both' }

  it_behaves_like 'metadata'

  describe 'scopes' do
    let!(:delivery_methods) { create_list(:delivery_method, 2, display_on: 'both') }
    let!(:frontend_delivery_methods) { create_list(:delivery_method, 2, display_on: 'front_end') }
    let!(:backend_delivery_methods) { create_list(:delivery_method, 2, display_on: 'back_end') }

    describe '.available' do
      subject { described_class.available }

      it { is_expected.to match_array(delivery_methods) }
    end

    describe '.available_on_front_end' do
      subject { described_class.available_on_front_end }

      it { is_expected.to match_array(delivery_methods + frontend_delivery_methods) }
    end

    describe '.available_on_back_end' do
      subject { described_class.available_on_back_end }

      it { is_expected.to match_array(delivery_methods + backend_delivery_methods) }
    end
  end

  describe '#requires_zone_check?' do
    it 'returns true if the shipping method is not digital' do
      expect(delivery_method.requires_zone_check?).to be_truthy
    end

    it 'returns false if the shipping method is digital' do
      delivery_method = create(:digital_delivery_method)
      expect(delivery_method.requires_zone_check?).to be_falsey
    end
  end

  context 'calculators' do
    it "rejects calculators that don't inherit from Spree::ShippingCalculator" do
      allow(described_class).to receive_message_chain(:spree_calculators, :shipping_methods).and_return([
                                                                                                                Spree::Calculator::Shipping::FlatPercentItemTotal,
                                                                                                                Spree::Calculator::Shipping::PriceSack,
                                                                                                                Spree::Calculator::FlatRate,
                                                                                                                DummyShippingCalculator # included as regression test for https://github.com/spree/spree/issues/3109
                                                                                                              ])

      expect(described_class.calculators).to eq([Spree::Calculator::Shipping::FlatPercentItemTotal, Spree::Calculator::Shipping::PriceSack, DummyShippingCalculator])
      expect(described_class.calculators).not_to eq([Spree::Calculator::FlatRate])
    end
  end

  # Regression test for #4492
  context '#shipments' do
    let!(:delivery_method) { create(:delivery_method) }
    let!(:shipment) do
      shipment = create(:shipment)
      shipment.shipping_rates.create!(delivery_method: delivery_method)
      shipment
    end

    it 'can gather all the related shipments' do
      expect(delivery_method.shipments).to include(shipment)
    end
  end

  context 'validations' do
    it 'validates presence of name' do
      subject.valid?
      expect(subject.errors.messages[:name].size).to eq(1)
    end

    it 'defaults display_on and rejects explicit blank' do
      expect(subject.display_on).to eq('both')

      subject.display_on = nil
      subject.valid?
      expect(subject.errors.messages[:display_on].size).not_to be_zero
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
    let(:delivery_method) { create(:delivery_method) }

    it 'soft-deletes when destroy is called' do
      delivery_method.destroy
      expect(delivery_method.deleted_at).not_to be_blank
    end
  end

  describe '#available_to_display?' do
    context 'when available on frontend' do
      it { expect(frontend_delivery_method.available_to_display?(described_class::DISPLAY_ON_FRONT_END)).to be true }
      it { expect(backend_delivery_method.available_to_display?(described_class::DISPLAY_ON_FRONT_END)).to be false }
      it { expect(front_and_back_end_delivery_method.available_to_display?(described_class::DISPLAY_ON_FRONT_END)).to be true }
    end

    context 'when available on backend' do
      it { expect(frontend_delivery_method.available_to_display?(described_class::DISPLAY_ON_BACK_END)).to be false }
      it { expect(backend_delivery_method.available_to_display?(described_class::DISPLAY_ON_BACK_END)).to be true }
      it { expect(front_and_back_end_delivery_method.available_to_display?(described_class::DISPLAY_ON_BACK_END)).to be true }
    end
  end

  describe '#frontend?' do
    it { expect(frontend_delivery_method.send(:frontend?)).to be true }
    it { expect(backend_delivery_method.send(:frontend?)).to be false }
    it { expect(front_and_back_end_delivery_method.send(:frontend?)).to be true }
  end

  describe '#backend?' do
    it { expect(frontend_delivery_method.send(:backend?)).to be false }
    it { expect(backend_delivery_method.send(:backend?)).to be true }
    it { expect(front_and_back_end_delivery_method.send(:backend?)).to be true }
  end

  describe '#delivery_range' do
    context 'without set estimated_transit_business_days_min and estimated_transit_business_days_max' do
      it { expect(delivery_method.delivery_range).to be_nil }
    end

    context 'with set estimated_transit_business_days_min and estimated_transit_business_days_max' do
      let(:delivery_method) { build(:delivery_method, estimated_transit_business_days_min: 1, estimated_transit_business_days_max: 2) }

      it { expect(delivery_method.delivery_range).to eq('1-2') }
    end

    context 'when both are the same' do
      let(:delivery_method) { build(:delivery_method, estimated_transit_business_days_min: 1, estimated_transit_business_days_max: 1) }

      it { expect(delivery_method.delivery_range).to eq('1') }
    end

    context "when only one transit day value is set" do
      context "when only minimum day is set" do
        let(:delivery_method) { build(:delivery_method, estimated_transit_business_days_min: 1) }

        it { expect(delivery_method.delivery_range).to eq('1') }
      end

      context "when only maximum day is set" do
        let(:delivery_method) { build(:delivery_method, estimated_transit_business_days_max: 2) }

        it { expect(delivery_method.delivery_range).to eq('2') }
      end
    end
  end

  describe '#display_estimated_price' do
    it { expect(delivery_method.display_estimated_price).to eq('Flat rate: $10.00') }

    context 'with the free rate' do
      let(:delivery_method) { build(:free_delivery_method) }

      it { expect(delivery_method.display_estimated_price).to eq('Flat rate: Free') }
    end
  end
end
