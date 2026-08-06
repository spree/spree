require 'spec_helper'

describe Spree::TaxProvider::Base, type: :model do
  subject(:provider) { described_class.new }

  let(:order) { create(:order_with_line_items, line_items_count: 1) }

  describe '#estimate' do
    it 'is the one method a provider must implement' do
      expect { provider.estimate(order) }.to raise_error(NotImplementedError, /estimate/)
    end

    it 'accepts the full typed input set' do
      expect do
        provider.estimate(order, order.line_items.to_a, tax_date: Time.current,
                                                        tax_identifier: nil, exemptions: [], context: { 'key' => 'value' })
      end.to raise_error(NotImplementedError)
    end
  end

  describe 'lifecycle methods' do
    it 'no-ops for a provider without a remote ledger' do
      expect(provider.commit(order)).to be_nil
      expect(provider.void(order)).to be_nil
      expect(provider.refund(order, [], tax_date: order.completed_at)).to be_nil
    end

    it 'takes the refunded items rather than an amount' do
      expect(provider.method(:refund).parameters).to eq([[:req, :order], [:req, :return_items], [:key, :tax_date]])
    end
  end

  describe 'capability declarations' do
    it 'claims everything is supported until a provider says otherwise' do
      expect(described_class.unsupported_capabilities).to eq([])
      expect(described_class.available_for_store?(order.store)).to be(true)
    end

    it 'is answerable without instantiating the provider' do
      expect(described_class).to respond_to(:unsupported_capabilities)
      expect(described_class).to respond_to(:available_for_store?)
    end
  end

  describe 'the internal provider' do
    it 'declares the domains rate configuration cannot express' do
      expect(Spree::TaxProvider::Internal.unsupported_capabilities).to(
        contain_exactly(:us_local_tax, :reverse_charge, :oss_thresholds)
      )
    end

    it 'is available for any store, needing no credentials' do
      expect(Spree::TaxProvider::Internal.available_for_store?(order.store)).to be(true)
    end
  end

  it 'no longer answers a standalone exemption question' do
    expect(provider).not_to respond_to(:exempt?)
  end
end
