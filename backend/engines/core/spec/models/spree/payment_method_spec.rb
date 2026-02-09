require 'spec_helper'

describe Spree::PaymentMethod, type: :model do
  it_behaves_like 'metadata'

  let(:store) { @default_store }

  # register test gateways
  before do
    Spree.payment_methods << TestGateway
    Spree.payment_methods << Spree::Gateway::Test
  end

  context 'visibility scopes' do
    before do
      ['both', 'front_end', 'back_end'].each do |display_on|
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
      expect(Spree::PaymentMethod.count).to eq(3)
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
        expect(methods.size).to eq(3)
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

  describe '#available_for_order?' do
    subject { payment_method.available_for_order?(order) }

    let(:payment_method) { create(:credit_card_payment_method) }
    let(:order) { create(:order, total: 100) }

    context 'when the order is not covered by store credit' do
      it { is_expected.to be(true) }
    end

    context 'when the order is partially covered by store credit' do
      let!(:store_credit_payment) { create(:store_credit_payment, order: order, amount: 50) }

      it { is_expected.to be(true) }
    end

    context 'when the order is fully covered by store credit' do
      let!(:store_credit_payment) { create(:store_credit_payment, order: order, amount: 100) }

      it { is_expected.to be(false) }
    end
  end

  describe '#available_for_store?' do
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

  describe '#source_required?' do
    let(:payment_method) { create(:credit_card_payment_method) }

    it { expect(payment_method.source_required?).to be true }
  end

  describe '#payment_source_class' do
    let(:payment_method) { build(:credit_card_payment_method) }

    it { expect(payment_method.payment_source_class).to eq(Spree::CreditCard) }
  end

  describe '#payment_icon_name' do
    it { expect(build(:credit_card_payment_method, type: 'Spree::Gateway::AuthorizeNetGateway').payment_icon_name).to eq('authorizenet') }
  end

  context 'when payment method is destroyed' do
    let(:payment_method) { create(:credit_card_payment_method) }
    let!(:payment) { create(:payment, payment_method: payment_method, source: credit_card) }
    let!(:credit_card) { create(:credit_card, payment_method: payment_method) }
    let!(:gateway_customer) { create(:gateway_customer, payment_method: payment_method) }

    it 'destroys the payment method' do
      expect { payment_method.destroy }.to change(Spree::PaymentMethod, :count).by(-1).and change(Spree::CreditCard, :count).by(-1).and change(Spree::GatewayCustomer, :count).by(-1)
      expect(payment.reload.payment_method).to be_nil
      expect(credit_card.reload.payment_method).to be_nil
      expect(credit_card.reload.deleted_at).not_to be_nil
    end
  end
end
