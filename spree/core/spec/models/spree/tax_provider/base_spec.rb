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

  describe 'self-description for the admin' do
    it 'presents id, name, availability and limits' do
      hash = Spree::TaxProvider::Internal.to_api_hash(order.store)

      expect(hash[:id]).to eq('Spree::TaxProvider::Internal')
      expect(hash[:name]).to eq('Internal')
      expect(hash[:available]).to be(true)
      expect(hash[:default]).to be(true)
      expect(hash[:unsupported_capabilities].map { |capability| capability[:key] }).to eq(
        %w[us_local_tax reverse_charge oss_thresholds]
      )
    end

    it 'says what each limit costs the merchant, not just its name' do
      local_tax = Spree::TaxProvider::Internal.unsupported_capability_details.
                  find { |capability| capability[:key] == 'us_local_tax' }

      expect(local_tax[:label]).to eq('US local tax')
      expect(local_tax[:description]).to include('County, city and district')
    end

    it 'falls back to a humanized key for a capability with no strings' do
      stub_const('SpecOddProvider', Class.new(described_class) do
        def self.unsupported_capabilities
          [:margin_scheme_goods]
        end
      end)

      capability = SpecOddProvider.unsupported_capability_details.sole

      expect(capability[:label]).to eq('Margin scheme goods')
      expect(capability).not_to have_key(:description)
    end

    it 'lets a provider gem name itself rather than wear a mangled class name' do
      stub_const('SpreeTaxAvalara::TaxProvider', Class.new(described_class) do
        def self.display_name
          'Avalara AvaTax'
        end
      end)

      expect(SpreeTaxAvalara::TaxProvider.to_api_hash(order.store)[:name]).to eq('Avalara AvaTax')
      expect(SpreeTaxAvalara::TaxProvider.to_api_hash(order.store)[:default]).to be(false)
    end
  end

  describe 'Spree.default_tax_provider' do
    it 'is the internal provider out of the box' do
      expect(Spree.default_tax_provider).to eq(Spree::TaxProvider::Internal)
    end

    it 'returns a class, so a caller that only names it pays for no instance' do
      expect(Spree.default_tax_provider).to be_a(Class)
    end

    it 'accepts a class name, for an initializer naming a provider before autoload' do
      original = Rails.application.config.spree.default_tax_provider
      Spree.default_tax_provider = 'Spree::TaxProvider::Internal'

      expect(Spree.default_tax_provider).to eq(Spree::TaxProvider::Internal)
      expect(Spree.default_tax_provider.new).to be_a(Spree::TaxProvider::Internal)
    ensure
      Spree.default_tax_provider = original
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
