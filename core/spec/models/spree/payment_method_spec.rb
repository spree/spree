require 'spec_helper'

describe Spree::PaymentMethod, type: :model do
  it_behaves_like 'metadata'

  let(:store) { create(:store) }

  context 'visibility scopes' do
    before do
      [nil, '', 'both', 'front_end', 'back_end'].each do |display_on|
        Spree::Gateway::Test.create(
          name: 'Display Both',
          display_on: display_on,
          active: true,
          description: 'foofah',
          stores: [store]
        )
      end
    end

    it 'has 5 total methods' do
      expect(Spree::PaymentMethod.count).to eq(5)
    end

    describe '#available' do
      it 'returns all methods available to front-end/back-end' do
        methods = Spree::PaymentMethod.available
        expect(methods.size).to eq(3)
        expect(methods.pluck(:display_on)).to eq(['both', 'front_end', 'back_end'])
      end
    end

    describe '#available_on_front_end' do
      it 'returns all methods available to front-end' do
        methods = Spree::PaymentMethod.available_on_front_end
        expect(methods.size).to eq(2)
        expect(methods.pluck(:display_on)).to eq(['both', 'front_end'])
      end
    end

    describe '#available_on_back_end' do
      it 'returns all methods available to back-end' do
        methods = Spree::PaymentMethod.available_on_back_end
        expect(methods.size).to eq(2)
        expect(methods.pluck(:display_on)).to eq(['both', 'back_end'])
      end
    end

    describe '#for_store' do
      it 'returns all methods available to front-end/back-end for a store' do
        store_2 = create(:store)
        method_from_other_store = Spree::Gateway::Test.create(
          name: 'Display Both',
          active: true,
          description: 'foofah',
          stores: [store_2]
        )
        methods = Spree::PaymentMethod.for_store(store)
        expect(methods).not_to include(method_from_other_store)
        expect(methods.size).to eq(5)
      end
    end
  end

  describe '#auto_capture?' do
    class TestGateway < Spree::Gateway
      def provider_class
        Provider
      end
    end

    subject { gateway.auto_capture? }

    let(:gateway) { TestGateway.new }

    context 'when auto_capture is nil' do
      before do
        expect(Spree::Config).to receive('[]').with(:auto_capture).and_return(auto_capture)
      end

      context 'and when Spree::Config[:auto_capture] is false' do
        let(:auto_capture) { false }

        it 'is false' do
          expect(gateway.auto_capture).to be_nil
          expect(subject).to be false
        end
      end

      context 'and when Spree::Config[:auto_capture] is true' do
        let(:auto_capture) { true }

        it 'is true' do
          expect(gateway.auto_capture).to be_nil
          expect(subject).to be true
        end
      end
    end

    context 'when auto_capture is not nil' do
      before do
        gateway.auto_capture = auto_capture
      end

      context 'and is true' do
        let(:auto_capture) { true }

        it 'is true' do
          expect(subject).to be true
        end
      end

      context 'and is false' do
        let(:auto_capture) { false }

        it 'is true' do
          expect(subject).to be false
        end
      end
    end
  end

  describe '#available_for_store?' do
    let!(:store) { create(:store) }
    let!(:store_1) { create(:store) }
    let!(:pm) { create(:credit_card_payment_method, stores: [store]) }

    it 'returns true when passed a nil value' do
      eligible = pm.available_for_store?(nil)
      expect(eligible).to be true
    end

    it 'returns false if currenct store id is not included' do
      ineligible = pm.available_for_store?(store_1)
      expect(ineligible).to be false
    end

    it 'returns true if currenct store id is included' do
      eligible = pm.available_for_store?(store)
      expect(eligible).to be true
    end
  end

  describe '#ensure_store_presence' do
    let(:valid_record) { build(:payment_method, stores: [create(:store)]) }
    let(:invalid_record) { build(:payment_method, stores: []) }

    it { expect(valid_record).to be_valid }
    it { expect(invalid_record).not_to be_valid }

    context 'validation disabled' do
      context 'method overwrite' do
        before { allow_any_instance_of(described_class).to receive(:disable_store_presence_validation?).and_return(true) }

        it { expect(valid_record).to be_valid }
        it { expect(invalid_record).to be_valid }
      end

      context 'preference set' do
        before { Spree::Config[:disable_store_presence_validation] = true }

        it { expect(valid_record).to be_valid }
        it { expect(invalid_record).to be_valid }
      end
    end
  end

  describe '#source_required?' do
    let(:payment_method) { create(:credit_card_payment_method) }

    it { expect(payment_method.source_required?).to be true }
  end

  describe '#payment_source_class' do
    let(:payment_method) { create(:credit_card_payment_method) }

    it { expect(payment_method.payment_source_class).to eq(Spree::CreditCard) }
  end
end
