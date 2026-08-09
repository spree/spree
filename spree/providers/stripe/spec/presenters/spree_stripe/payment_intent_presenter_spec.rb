require 'spec_helper'

RSpec.describe SpreeStripe::PaymentIntentPresenter do
  subject { presenter.call }

  let(:presenter) do
    described_class.new(
      amount: amount,
      order: order,
      customer: customer,
      payment_method_id: payment_method_id
    )
  end

  let(:order_number) { 'R123456789' }
  let(:store) { @default_store }
  let(:order) { create(:order, number: order_number, store: store) }
  let(:customer) { 'cus_123' }
  let(:amount) { 100 }
  let(:payment_method_id) { nil }

  let(:statement_descriptor_prefix) { 'ORDER123' }
  let(:statement_descriptor_stub) do
    instance_double(SpreeStripe::StatementDescriptorSuffixPresenter, call: statement_descriptor_prefix)
  end

  let(:base_payload) do
    {
      amount: amount,
      customer: customer,
      currency: order.currency,
      statement_descriptor_suffix: statement_descriptor_prefix,
      automatic_payment_methods: { enabled: true },
      transfer_group: order.number,
      metadata: { spree_order_id: order.id }
    }
  end

  let(:new_payment_method_payload) do
    {
      payment_method_options: {
        card: { setup_future_usage: 'off_session' },
        sepa_debit: { setup_future_usage: 'off_session' }
      }
    }
  end

  before do
    allow(SpreeStripe::StatementDescriptorSuffixPresenter).to receive(:new).
      with(order_description: order.number).and_return(statement_descriptor_stub)
  end

  context 'when payment_method_id is present' do
    let(:payment_method_id) { 'pm_123' }

    it 'returns a payload with the saved payment method' do
      expect(subject).to eq(base_payload.merge(payment_method: payment_method_id))
    end
  end

  context 'when payment_method_id is not present' do
    it 'returns a payload asking Stripe to save the new payment method' do
      expect(subject).to eq(base_payload.merge(new_payment_method_payload))
    end
  end

  context 'when the order has no customer' do
    let(:order) { create(:order, customer: nil, email: 'john@snow.org', number: order_number, store: store) }

    it 'returns a payload asking Stripe to save the new payment method' do
      expect(subject).to eq(base_payload.merge(new_payment_method_payload))
    end
  end

  context 'when ship_address is present' do
    let(:ship_address) { create(:address) }

    before { allow(order).to receive(:ship_address).and_return(ship_address) }

    it 'returns a payload with the shipping address' do
      expect(subject).to eq(
        base_payload.merge(new_payment_method_payload).merge(
          shipping: {
            address: {
              city: ship_address.city,
              country: ship_address.country_iso,
              line1: ship_address.address1,
              line2: ship_address.address2,
              postal_code: ship_address.zipcode,
              state: ship_address.state_abbr
            },
            name: ship_address.full_name
          }
        )
      )
    end

    context 'when the ship address has no address1' do
      let(:ship_address) { build(:address, address1: nil) }

      it 'omits the shipping address, which Stripe would reject' do
        expect(subject).not_to have_key(:shipping)
      end
    end
  end

  describe 'capture_method handling' do
    context 'when capture_method is nil (default)' do
      it 'does not include capture_method in the payload' do
        expect(subject).not_to have_key(:capture_method)
      end
    end

    context 'when capture_method is "manual"' do
      let(:presenter) do
        described_class.new(
          amount: amount,
          order: order,
          customer: customer,
          payment_method_id: payment_method_id,
          capture_method: 'manual'
        )
      end

      it 'includes capture_method: manual in the payload (new payment method flow)' do
        expect(subject[:capture_method]).to eq('manual')
      end

      context 'with a saved payment method' do
        let(:payment_method_id) { 'pm_123' }

        it 'includes capture_method: manual in the payload' do
          expect(subject[:capture_method]).to eq('manual')
        end
      end
    end

    context 'when capture_method is "automatic"' do
      let(:presenter) do
        described_class.new(
          amount: amount,
          order: order,
          customer: customer,
          payment_method_id: payment_method_id,
          capture_method: 'automatic'
        )
      end

      it 'does not include capture_method (Stripe default)' do
        expect(subject).not_to have_key(:capture_method)
      end
    end
  end
end
