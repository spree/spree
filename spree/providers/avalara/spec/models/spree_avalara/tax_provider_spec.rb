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

  # The idempotency predicates are real logic, so the double delegates to a real
  # client rather than asserting a canned answer.
  let(:predicates) do
    SpreeAvalara::Client.new(account_number: 'a', license_key: 'b',
                             endpoint: SpreeAvalara::Integration::SANDBOX_ENDPOINT)
  end

  before do
    Rails.cache.clear
    allow(SpreeAvalara::Integration).to receive(:active_for!).with(@default_store).and_return(integration)
    allow(SpreeAvalara::Integration).to receive(:active_for).with(@default_store).and_return(integration)
    allow(integration).to receive(:client).and_return(client)
    allow(client).to receive(:create_transaction).and_return(response)
    allow(client).to receive(:duplicate_document_error?) { |error| predicates.duplicate_document_error?(error) }
    allow(client).to receive(:already_voided_error?) { |error| predicates.already_voided_error?(error) }
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
    # Start from a wrong value, so the example fails if nothing writes it.
    line_item.update_column(:pre_tax_amount, 0)

    provider.estimate(cart)

    expect(line_item.reload.pre_tax_amount).to eq(line_item.taxable_basis)
  end

  # Internal restores the full basis when no rate matches; sweeping has to do the
  # same, or an inclusive market keeps reporting a net figure for an item that is
  # no longer taxed at all.
  it 'restores the pre-tax amount when it sweeps and has nothing to say' do
    provider.estimate(cart)
    line_item.update_column(:pre_tax_amount, 1)
    cart.update!(ship_address: nil, bill_address: nil)

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
    # Asserting the absence of rows is not enough — that would also hold for an
    # implementation that asked Avalara and threw the answer away. A cart with no
    # address yet is most of a cart's life, and it must cost nothing.
    it 'never asks Avalara about a sale with nowhere to ship' do
      cart.update!(ship_address: nil, bill_address: nil)

      provider.estimate(cart.reload)

      expect(client).not_to have_received(:create_transaction)
      expect(cart.tax_lines.reload).to be_empty
    end

    it 'never asks Avalara when there is nothing to tax' do
      line_item.destroy!

      provider.estimate(cart.reload)

      expect(client).not_to have_received(:create_transaction)
    end

    it 'sweeps rows it wrote earlier once the address goes away' do
      provider.estimate(cart)
      expect(cart.tax_lines.reload).to be_present

      cart.update!(ship_address: nil, bill_address: nil)
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

  describe '#commit' do
    let(:order) { create(:order, store: @default_store, completed_at: Time.current, ship_address: address, bill_address: address) }
    let!(:order_line) { create(:line_item, order: order, cart: nil, price: 100) }

    before { allow(client).to receive(:create_or_adjust_transaction).and_return('id' => 987_654) }

    it 'files the sale and keeps the document id on the order' do
      provider.commit(order)

      expect(client).to have_received(:create_or_adjust_transaction) do |args|
        model = args[:createTransactionModel]
        expect(model[:type]).to eq('SalesInvoice')
        expect(model[:code]).to eq(order.number)
      end
      expect(order.reload.metadata['avalara_transaction_id']).to eq('987654')
    end

    # Completion is replayable, so filing the same code twice is the success it
    # describes rather than an error to surface.
    # A replay cannot learn the document id — the refusal carries none — so what
    # matters is that it does not raise and does not invent one. Void and refund
    # key on the order number, not this value.
    it 'treats an already-filed document as success' do
      allow(client).to receive(:create_or_adjust_transaction).
        and_raise(SpreeAvalara::RequestError.new('Document already exists.', status: 400,
                                                 details: { 'code' => 'DocumentAlreadyExists' }))

      expect { provider.commit(order) }.not_to raise_error
      expect(order.reload.metadata['avalara_transaction_id']).to be_nil
    end

    it 'raises on any other refusal' do
      allow(client).to receive(:create_or_adjust_transaction).
        and_raise(SpreeAvalara::RequestError.new('Company not found.', status: 400,
                                                 details: { 'code' => 'EntityNotFoundError' }))

      expect { provider.commit(order) }.to raise_error(SpreeAvalara::RequestError)
    end
  end

  describe '#void' do
    let(:order) { create(:order, store: @default_store, completed_at: Time.current) }

    before { allow(client).to receive(:void_transaction).and_return('status' => 'Cancelled') }

    it 'reverses the document by its order number' do
      provider.void(order)

      expect(client).to have_received(:void_transaction).with(order.number)
    end

    # Nothing was filed through an integration that is not connected.
    it 'has nothing to reverse without a connected integration' do
      allow(SpreeAvalara::Integration).to receive(:active_for).with(@default_store).and_return(nil)

      expect { provider.void(order) }.not_to raise_error
      expect(client).not_to have_received(:void_transaction)
    end

    it 'treats an already-voided document as success' do
      allow(client).to receive(:void_transaction).
        and_raise(SpreeAvalara::RequestError.new('The transaction has already been cancelled.', status: 400,
                                                 details: { 'code' => 'TransactionAlreadyCancelled' }))

      expect { provider.void(order) }.not_to raise_error
    end

    # Cancelling an order must not depend on a tax service being reachable.
    it 'does not fail closed the way estimate does' do
      allow(client).to receive(:void_transaction).
        and_raise(SpreeAvalara::RequestError.new('Document not found.', status: 404,
                                                 details: { 'code' => 'EntityNotFoundError' }))

      expect { provider.void(order) }.not_to raise_error
    end
  end

  describe '#refund' do
    let(:order) { create(:order, store: @default_store, completed_at: Time.current, ship_address: address, bill_address: address) }
    let(:refunded_line) { create(:line_item, order: order, cart: nil, price: 100, quantity: 4) }
    let(:return_items) do
      [instance_double(Spree::ReturnLineItem, line_item: refunded_line, received_quantity: 2,
                                              return: instance_double(Spree::Return, number: 'RET1'))]
    end

    before do
      refunded_line.update_column(:pre_tax_amount, 400)
      allow(client).to receive(:create_transaction).and_return('id' => 5)
    end

    it 'credits the returned lines against the filed document' do
      provider.refund(order, return_items)

      expect(client).to have_received(:create_transaction) do |model|
        expect(model[:type]).to eq('ReturnInvoice')
        expect(model[:code]).to eq("#{order.number}-RET1")
        expect(model[:lines].sole[:amount]).to eq(-200)
      end
    end

    it 'files nothing when no units came back' do
      empty = [instance_double(Spree::ReturnLineItem, line_item: refunded_line, received_quantity: 0,
                                                      return: instance_double(Spree::Return, number: 'RET1'))]

      provider.refund(order, empty)

      expect(client).not_to have_received(:create_transaction)
    end

    it 'treats a replayed credit as success' do
      allow(client).to receive(:create_transaction).
        and_raise(SpreeAvalara::RequestError.new('Document already exists.', status: 400,
                                                 details: { 'code' => 'DocumentAlreadyExists' }))

      expect { provider.refund(order, return_items) }.not_to raise_error
    end
  end

  it 'has no opinion on the tax of a service the platform supplies' do
    expect(provider.service_tax_rate(address: address, store: @default_store)).to be_nil
  end
end
