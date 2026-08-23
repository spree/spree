require 'spec_helper'

RSpec.describe Spree::Commissions::ResolveTaxRate do
  let(:store) { @default_store }
  let(:billing_address) { create(:address, country_iso: 'DE') }
  let(:seller) { create(:seller, :approved, store: store, billing_address: billing_address) }
  let(:order) { create(:order, store: store) }
  let(:rate) { create(:commission_rate, store: store) }

  def resolve
    described_class.call(rate: rate, seller: seller, order: order).value
  end

  def resolved_rate
    resolve.rate
  end

  it 'prefers an explicit override on the rate' do
    rate.update!(commission_tax_rate: 0.19)
    allow_any_instance_of(Spree::TaxProvider::Internal).to receive(:service_tax_rate).and_return(0.21)

    expect(resolved_rate).to eq(0.19)
  end

  it 'asks the tax engine when the rate names no rate of its own' do
    allow_any_instance_of(Spree::TaxProvider::Internal).to receive(:service_tax_rate).and_return(0.21)

    expect(resolved_rate).to eq(0.21)
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

    expect(resolved_rate).to eq(0.2)
  end

  it 'charges nothing when nothing is configured anywhere' do
    allow_any_instance_of(Spree::TaxProvider::Internal).to receive(:service_tax_rate).and_return(nil)

    expect(resolved_rate).to eq(0)
  end

  # Commission is written while an order is being placed, so a tax service
  # being down must not cost the marketplace the sale.
  it 'falls back rather than raising when the engine fails' do
    stub_store_preferences(store, default_commission_tax_rate: 0.2)
    allow_any_instance_of(Spree::TaxProvider::Internal).
      to receive(:service_tax_rate).and_raise(StandardError, 'tax service unreachable')

    expect(resolved_rate).to eq(0.2)
  end

  # The rate alone cannot justify a figure on an invoice; the treatment can.
  describe 'the treatment it records' do
    it 'takes the jurisdiction from the seller own address when the engine answers' do
      allow_any_instance_of(Spree::TaxProvider::Internal).to receive(:service_tax_rate).and_return(0.19)

      tax = resolve

      expect(tax.taxability_reason).to eq('standard_rated')
      expect(tax.country_code).to eq('DE')
    end

    # A jurisdiction that taxes the fee at nothing has made a decision, and an
    # invoice has to show it — unlike a marketplace that simply charges no tax.
    it 'calls a zero from the engine zero-rated, not untaxed' do
      allow_any_instance_of(Spree::TaxProvider::Internal).to receive(:service_tax_rate).and_return(0)

      expect(resolve.taxability_reason).to eq('zero_rated')
    end

    it 'claims no jurisdiction for a rate somebody typed' do
      rate.update!(commission_tax_rate: 0.19)

      tax = resolve

      expect(tax.taxability_reason).to eq('standard_rated')
      expect(tax.country_code).to be_nil
    end

    it 'records no treatment at all when nothing taxes the fee' do
      allow_any_instance_of(Spree::TaxProvider::Internal).to receive(:service_tax_rate).and_return(nil)

      expect(resolve.taxability_reason).to be_nil
    end
  end
end