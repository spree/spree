require 'spec_helper'

RSpec.describe Spree::Commissions::ResolveTaxRate do
  let(:store) { @default_store }
  let(:billing_address) { create(:address, country_iso: 'DE') }
  let(:vendor) { create(:vendor, :approved, store: store, billing_address: billing_address) }
  let(:order) { create(:order, store: store) }
  let(:rate) { create(:commission_rate, store: store) }

  def resolve
    described_class.call(rate: rate, vendor: vendor, order: order).value
  end

  it 'prefers an explicit override on the rate' do
    rate.update!(commission_tax_rate: 0.19)
    allow_any_instance_of(Spree::TaxProvider::Internal).to receive(:service_tax_rate).and_return(0.21)

    expect(resolve).to eq(0.19)
  end

  it 'asks the tax engine when the rate names no rate of its own' do
    allow_any_instance_of(Spree::TaxProvider::Internal).to receive(:service_tax_rate).and_return(0.21)

    expect(resolve).to eq(0.21)
  end

  # The commission is invoiced to the seller's business, so it is taxed where
  # that business sits — not where the customer's parcel went.
  it 'asks against the seller billing address' do
    expect_any_instance_of(Spree::TaxProvider::Internal).
      to receive(:service_tax_rate).with(address: billing_address, store: store).and_return(0.19)

    resolve
  end

  it 'falls back to the store default when the engine has no opinion' do
    stub_store_preferences(store, default_commission_tax_rate: 0.2)
    allow_any_instance_of(Spree::TaxProvider::Internal).to receive(:service_tax_rate).and_return(nil)

    expect(resolve).to eq(0.2)
  end

  it 'charges nothing when nothing is configured anywhere' do
    allow_any_instance_of(Spree::TaxProvider::Internal).to receive(:service_tax_rate).and_return(nil)

    expect(resolve).to eq(0)
  end

  # Commission is written while an order is being placed, so a tax service
  # being down must not cost the marketplace the sale.
  it 'falls back rather than raising when the engine fails' do
    stub_store_preferences(store, default_commission_tax_rate: 0.2)
    allow_any_instance_of(Spree::TaxProvider::Internal).
      to receive(:service_tax_rate).and_raise(StandardError, 'tax service unreachable')

    expect(resolve).to eq(0.2)
  end
end
