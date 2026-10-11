require 'spec_helper'

RSpec.describe Spree::Payment::GatewayOptions, type: :model do
  let(:options) { Spree::Payment::GatewayOptions.new(payment) }

  let(:payment) do
    double(
      Spree::Payment,
      owner: order,
      number: 'P1566',
      prefixed_id: 'py_k5nR8xLq',
      currency: 'EUR',
      payment_method: payment_method
    )
  end

  let(:payment_method) do
    double(
      Spree::Gateway::Bogus,
      exchange_multiplier: Spree::Gateway::FROM_DOLLAR_TO_CENT_RATE
    )
  end

  let(:order) do
    double(
      Spree::Order,
      email: 'test@email.com',
      customer_id: 144,
      last_ip_address: '0.0.0.0',
      number: 'R1444',
      delivery_total: '12.44'.to_d,
      additional_tax_total: '1.53'.to_d,
      item_total: '15.11'.to_d,
      discount_total: '2.57'.to_d,
      bill_address: bill_address,
      ship_address: ship_address
    )
  end

  let(:bill_address) do
    double Spree::Address, gateway_hash: { bill: :address }
  end

  let(:ship_address) do
    double Spree::Address, gateway_hash: { ship: :address }
  end

  describe '#to_hash' do
    subject { options.to_hash }

    let(:expected) do
      {
        email: 'test@email.com',
        customer: 'test@email.com',
        customer_id: 144,
        ip: '0.0.0.0',
        # The payment number already names its order, so this is no longer the
        # order number and the payment number concatenated.
        order_id: 'P1566',
        payment_id: 'P1566',
        # The stable lookup handle: the derived number cannot be queried (NULL
        # column on 6.0 rows) and shifts when a sibling is destroyed.
        payment_prefixed_id: 'py_k5nR8xLq',
        # The prefixed ID, not the number — a derived number can shift if an
        # earlier sibling payment is destroyed, and a shifted key could collide
        # with one already used at the gateway.
        idempotency_key: 'spree-py_k5nR8xLq',
        shipping: '1244'.to_d,
        tax: '153'.to_d,
        subtotal: '1511'.to_d,
        discount: '257'.to_d,
        currency: 'EUR',
        billing_address: { bill: :address },
        shipping_address: { ship: :address }
      }
    end

    it { is_expected.to eq expected }
  end
end
