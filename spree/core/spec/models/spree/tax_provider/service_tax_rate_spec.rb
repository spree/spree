require 'spec_helper'

RSpec.describe 'Spree::TaxProvider service tax rate' do
  let(:store) { @default_store }
  let(:category) { Spree::TaxCategory.default(store) || create(:tax_category, store: store, is_default: true) }
  let(:address) { create(:address, country_iso: 'DE') }

  describe Spree::TaxProvider::Base do
    # A provider that cannot price a service supply says nothing rather than
    # zero, so its caller falls back to a configured default instead of
    # treating silence as "untaxed".
    it 'has no opinion by default' do
      expect(described_class.new.service_tax_rate(address: address, store: store)).to be_nil
    end
  end

  describe Spree::TaxProvider::Internal do
    subject(:provider) { described_class.new }

    it 'reads the rate configured for where the business sits' do
      create(:tax_rate, store: store, tax_category: category, amount: 0.19,
                        country_code: 'DE', included_in_price: false)

      expect(provider.service_tax_rate(address: address, store: store)).to eq(0.19)
    end

    it 'has no opinion when nothing is configured for that jurisdiction' do
      create(:tax_rate, store: store, tax_category: category, amount: 0.19,
                        country_code: 'FR', included_in_price: false)

      expect(provider.service_tax_rate(address: address, store: store)).to be_nil
    end

    it 'has no opinion without an address' do
      expect(provider.service_tax_rate(address: nil, store: store)).to be_nil
    end

    # A commission is quoted net and its VAT is added on top, so a rate
    # describing tax-inclusive consumer pricing does not describe this supply.
    it 'ignores rates configured as included in the price' do
      create(:tax_rate, store: store, tax_category: category, amount: 0.19,
                        country_code: 'DE', included_in_price: true)

      expect(provider.service_tax_rate(address: address, store: store)).to be_nil
    end

    it 'does not read another store rates' do
      other_store = create(:store)
      other_category = create(:tax_category, store: other_store, is_default: true)
      create(:tax_rate, store: other_store, tax_category: other_category, amount: 0.19,
                        country_code: 'DE', included_in_price: false)

      expect(provider.service_tax_rate(address: address, store: store)).to be_nil
    end
  end
end
