require 'spec_helper'

RSpec.describe SpreeAvalara::TaxProvider do
  subject(:provider) { described_class.new }

  let!(:integration) { create(:avalara_integration, :active, store: @default_store) }
  let(:address) { create(:address, city: 'Seattle', state_code: 'WA', country_code: 'US', zipcode: '98109') }
  let(:cart) { create(:cart, store: @default_store, ship_address: address, bill_address: address) }
  let!(:line_item) { create(:line_item, cart: cart, order: nil, price: 100) }
  let(:client) { instance_double(SpreeAvalara::Client) }

  def response(tax: 8.25, line_number: line_item.prefixed_id)
    {
      'lines' => [{
        'lineNumber' => line_number, 'lineAmount' => 100.0, 'taxCalculated' => tax,
        'taxIncluded' => false, 'exemptAmount' => 0.0, 'exemptCertId' => 0, 'exemptNo' => '',
        'details' => [{ 'country' => 'US', 'region' => 'WA', 'taxName' => 'WA STATE TAX',
                        'taxType' => 'Sales', 'rate' => 0.0825, 'taxCalculated' => tax,
                        'nonTaxableAmount' => 0.0, 'rateTypeCode' => 'G' }]
      }]
    }
  end

  before do
    Rails.cache.clear
    allow(SpreeAvalara::Integration).to receive(:active_for!).with(@default_store).and_return(integration)
    allow(integration).to receive(:client).and_return(client)
    allow(client).to receive(:create_transaction).and_return(response)
  end

  it 'registers itself as a selectable engine named after the service' do
    expect(Spree.tax_providers).to include(described_class)
    expect(described_class.display_name).to eq('Avalara AvaTax')
    expect(described_class.unsupported_capabilities).to eq([])
  end

  it 'writes one row per priced line' do
    provider.estimate(cart)

    row = cart.tax_lines.reload.sole
    expect(row.provider_id).to eq('avalara')
    expect(row.amount).to eq(8.25)
    expect(row.line_item_id).to eq(line_item.id)
    expect(row.taxability_reason).to eq('standard_rated')
  end

  # Replace-all set semantics: the second answer supersedes the first rather
  # than stacking on it.
  it 'replaces its rows rather than accumulating them' do
    provider.estimate(cart)
    allow(client).to receive(:create_transaction).and_return(response(tax: 9.5))
    Rails.cache.clear

    provider.estimate(cart)

    expect(cart.tax_lines.reload.map(&:amount)).to eq([9.5])
  end

  # The import VAT a landed-cost provider writes against a duty is not ours.
  it 'leaves another provider rows alone' do
    foreign = create(:tax_line, cart: cart, line_item: line_item, provider_id: 'internal', amount: 3)

    provider.estimate(cart)

    expect(cart.tax_lines.reload.pluck(:provider_id)).to contain_exactly('internal', 'avalara')
    expect(foreign.reload).to be_present
  end

  it 'records what the line is worth before tax' do
    provider.estimate(cart)

    expect(line_item.reload.pre_tax_amount).to eq(line_item.taxable_basis)
  end

  it 'takes included tax back out of the pre-tax amount' do
    included = response
    included['lines'].first['taxIncluded'] = true
    allow(client).to receive(:create_transaction).and_return(included)

    provider.estimate(cart)

    expect(line_item.reload.pre_tax_amount).to eq(line_item.taxable_basis - 8.25)
  end

  describe 'the response cache' do
    # The dummy app runs on :null_store, as test environments should, so the
    # cache needs a real store here to be observable at all.
    before { allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new) }

    it 'answers a repeated estimate without calling Avalara again' do
      provider.estimate(cart)
      provider.estimate(cart)

      expect(client).to have_received(:create_transaction).once
    end

    # An address change can flip inclusiveness as well as the rate, so it has to
    # bust the key rather than serve the previous calculation.
    it 'prices again when the tax address changes' do
      provider.estimate(cart)
      cart.update!(ship_address: create(:address, state_code: 'CA', country_code: 'US', zipcode: '92614'))

      provider.estimate(cart)

      expect(client).to have_received(:create_transaction).twice
    end
  end

  describe 'having no opinion' do
    it 'sweeps and returns when the sale has nowhere to ship' do
      provider.estimate(cart)
      cart.update!(ship_address: nil, bill_address: nil)

      provider.estimate(cart)

      expect(cart.tax_lines.reload).to be_empty
    end

    it 'sweeps and returns when there is nothing to tax' do
      provider.estimate(cart)
      line_item.destroy!

      provider.estimate(cart.reload)

      expect(cart.tax_lines.reload).to be_empty
    end
  end

  describe 'failing closed' do
    it 'raises when the store has no connected integration' do
      allow(SpreeAvalara::Integration).to receive(:active_for!).
        with(@default_store).and_raise(SpreeAvalara::NotConfiguredError)

      expect { provider.estimate(cart) }.to raise_error(SpreeAvalara::NotConfiguredError)
    end

    # Under-collecting silently is the failure mode this avoids.
    it 'raises rather than writing no rows when Avalara refuses' do
      allow(client).to receive(:create_transaction).
        and_raise(SpreeAvalara::RequestError.new('Company not found.', status: 400))

      expect { provider.estimate(cart) }.to raise_error(SpreeAvalara::RequestError)
    end

    it 'raises when Avalara prices a line that was never sent' do
      allow(client).to receive(:create_transaction).and_return(response(line_number: 'li_never_sent'))

      expect { provider.estimate(cart) }.to raise_error(SpreeAvalara::Error, /never sent/)
    end
  end
end
