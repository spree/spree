require 'spec_helper'

# What Avalara actually returns, played back from cassettes the maintainer
# records against a sandbox account. Every example here skips while its cassette
# is absent, so the suite stays green until Phase 7 records them — and the moment
# one exists, the claim it makes is checked against a real response rather than a
# fixture somebody wrote.
#
# Recording: see the README. Never hand-author a cassette.
RSpec.describe 'AvaTax API contract', :vcr do
  let(:credentials) do
    { preferred_account_number: ENV.fetch('AVATAX_ACCOUNT_NUMBER', 'recorded'),
      preferred_license_key: ENV.fetch('AVATAX_LICENSE_KEY', 'recorded'),
      preferred_company_code: ENV.fetch('AVATAX_COMPANY_CODE', 'AVALARA_COMPANY') }
  end
  let(:integration) { create(:avalara_integration, :active, store: @default_store, **credentials) }
  let(:provider) { SpreeAvalara::TaxProvider.new }

  def us_cart(state: 'WA', zipcode: '98109', city: 'Seattle')
    address = create(:address, city: city, state_code: state, country_code: 'US', zipcode: zipcode)
    cart = create(:cart, store: @default_store, ship_address: address, bill_address: address)
    create(:line_item, cart: cart, order: nil, price: 100)
    create(:stock_location, store: @default_store, default: true, country_code: 'US',
                            state_code: 'CA', city: 'Irvine', zipcode: '92614', address1: '2000 Main Street')
    cart.reload
  end

  describe 'ping' do
    # Deliberately without the :active trait, which answers can_connect? with a
    # stub — this example is about the real call.
    it 'reports an authenticated account', vcr: { cassette_name: 'ping/authenticated' } do
      connected = build(:avalara_integration, store: @default_store, **credentials)

      expect(connected.can_connect?).to be(true)
    end

    it 'reports a rejected key', vcr: { cassette_name: 'ping/unauthorized' } do
      rejected = build(:avalara_integration, store: @default_store, **credentials,
                                             preferred_license_key: 'deliberately-wrong')

      expect(rejected.can_connect?).to be(false)
      expect(rejected.connection_error_message).to be_present
    end
  end

  describe 'estimate' do
    it 'prices a US sale line by line', vcr: { cassette_name: 'estimate/us_multi_line' } do
      cart = us_cart
      allow(SpreeAvalara::Integration).to receive(:active_for).and_return(integration)

      provider.estimate(cart)

      rows = cart.tax_lines.reload.where(provider_id: 'avalara')
      expect(rows).to be_present
      expect(rows.map(&:taxability_reason)).to all(be_in(Spree::TaxLine.taxability_reasons))
      expect(rows.map(&:country_code)).to all(eq('US'))
    end

    it 'records a customer exemption Avalara applied',
       vcr: { cassette_name: 'estimate/exempt_entity_use_code' } do
      cart = us_cart
      allow(SpreeAvalara::Integration).to receive(:active_for).and_return(integration)
      exemption = Spree::TaxExemption.new(reason_code: 'RESALE', certificate_number: 'C-100')

      provider.estimate(cart, exemptions: [exemption])

      expect(cart.tax_lines.reload.map(&:taxability_reason)).to include('customer_exempt')
    end

    # The document-level example above cannot exercise the per-line keys, because
    # one order-wide claim goes on the document by design. This one carves a line
    # out so placement moves onto the line, and pins the certificate number
    # coming back — AvaTax ignores line keys it does not recognise without
    # complaining, so a wrong name here would silently drop the certificate.
    it 'records a per-line exemption with its certificate number',
       vcr: { cassette_name: 'estimate/exempt_per_line' } do
      cart = us_cart
      allow(SpreeAvalara::Integration).to receive(:active_for).and_return(integration)
      line = cart.line_items.first
      override = instance_double('override', item_id: line.prefixed_id, exempt?: true, reason_code: 'RESALE')
      exemption = Spree::TaxExemption.new(reason_code: 'RESALE', certificate_number: 'C-100',
                                          item_overrides: [override])

      provider.estimate(cart, exemptions: [exemption])

      row = cart.tax_lines.reload.find_by(line_item_id: line.id)
      expect(row.taxability_reason).to eq('customer_exempt')
      expect(row.data['avalara']['exemptNo']).to eq('C-100')
    end

    # The commonest zero-tax case, and the one the reason table originally got
    # wrong: the whole line reads exempt with no certificate behind it.
    it 'calls a destination with no nexus not_collecting',
       vcr: { cassette_name: 'estimate/no_nexus_destination' } do
      cart = us_cart(state: 'MT', zipcode: '59001', city: 'Absarokee')
      allow(SpreeAvalara::Integration).to receive(:active_for).and_return(integration)

      provider.estimate(cart)

      rows = cart.tax_lines.reload
      expect(rows.map(&:taxability_reason)).to include('not_collecting')
      expect(rows.map(&:taxability_reason)).not_to include('customer_exempt')
    end

    # Narrow but real: it pins the whole inclusiveness chain — the DE market
    # resolves as gross-priced, the request says taxIncluded, Avalara echoes it,
    # and the row records it. It says nothing about VAT arithmetic, because the
    # recording account has no EU registration and the rate comes back 0%.
    it 'marks rows included when the destination market prices gross',
       vcr: { cassette_name: 'estimate/eu_tax_inclusive' } do
      market = create(:market, store: @default_store, tax_inclusive: true)
      market.update!(country_codes: ['DE'])
      address = create(:address, country_code: 'DE', state_code: nil, city: 'Berlin', zipcode: '10115')
      cart = create(:cart, store: @default_store, ship_address: address, bill_address: address, market: market)
      create(:line_item, cart: cart, order: nil, price: 100)
      allow(SpreeAvalara::Integration).to receive(:active_for).and_return(integration)

      provider.estimate(cart.reload)

      rows = cart.tax_lines.reload
      # Guards the claim against going vacuous if the estimate ever writes nothing.
      expect(rows).not_to be_empty
      expect(rows.map(&:included)).to all(be(true))
    end
  end

  describe 'the document lifecycle' do
    let(:destination) { create(:address, city: 'New York', state_code: 'NY', country_code: 'US', zipcode: '10001') }
    let(:order) do
      create(:order, store: @default_store, completed_at: Time.current,
                     ship_address: destination, bill_address: destination)
    end
    let!(:sold) { create(:line_item, order: order, cart: nil, price: 100) }

    before do
      allow(SpreeAvalara::Integration).to receive(:active_for).and_return(integration)
      create(:stock_location, store: @default_store, default: true, country_code: 'US',
                              state_code: 'CA', city: 'Irvine', zipcode: '92614', address1: '2000 Main Street')
      # The void URL carries the document code, and VCR matches on the URI, so a
      # generated order number would never replay.
      order.update_column(:number, 'R-AVALARA-LIFECYCLE')
    end

    it 'files the sale', vcr: { cassette_name: 'commit/sales_invoice' } do
      provider.commit(order)

      expect(order.reload.metadata['avalara_transaction_id']).to be_present
    end

    # Completion is replayable, so the same code twice is success.
    it 'accepts a replayed filing', vcr: { cassette_name: 'commit/replayed' } do
      provider.commit(order)

      expect { provider.commit(order) }.not_to raise_error
    end

    it 'voids the document', vcr: { cassette_name: 'void/cancelled' } do
      provider.commit(order)

      expect { provider.void(order) }.not_to raise_error
    end

    it 'accepts voiding a document already voided', vcr: { cassette_name: 'void/already_voided' } do
      provider.commit(order)
      provider.void(order)

      expect { provider.void(order) }.not_to raise_error
    end
  end

  describe 'refund' do
    let(:destination) { create(:address, city: 'New York', state_code: 'NY', country_code: 'US', zipcode: '10001') }
    # Sold well in the past, so the tax-date override has something to prove: a
    # credit taxed as of today would silently use today's rates.
    let(:sold_on) { Time.utc(2024, 1, 15, 12, 0, 0) }
    let(:order) do
      create(:order, store: @default_store, completed_at: sold_on,
                     ship_address: destination, bill_address: destination)
    end
    let(:line_item) { create(:line_item, order: order, cart: nil, price: 100, quantity: 2) }
    let(:return_items) do
      [instance_double(Spree::ReturnLineItem, line_item: line_item, received_quantity: 1,
                                              return: instance_double(Spree::Return, number: 'RET1'))]
    end

    before do
      allow(SpreeAvalara::Integration).to receive(:active_for).and_return(integration)
      create(:stock_location, store: @default_store, default: true, country_code: 'US',
                              state_code: 'CA', city: 'Irvine', zipcode: '92614', address1: '2000 Main Street')
      line_item.update_column(:pre_tax_amount, 200)
    end

    it 'credits the returned line', vcr: { cassette_name: 'refund/return_invoice' } do
      expect { provider.refund(order, return_items) }.not_to raise_error
    end

    # AvaTax ignores an override key it does not recognise without complaining,
    # so the only proof the override landed is the date it taxed the credit on.
    it 'taxes the credit as of the original sale', vcr: { cassette_name: 'refund/tax_date_override' } do
      # A fresh document code per recording: the other refund examples reuse the
      # order factory's number, so they collide with documents recording left
      # behind — which is what their duplicate handling wants, and what this
      # example must avoid, since it needs a response to read.
      order.update_column(:number, "R-TAXDATE-#{Time.now.to_i}")
      credited = nil
      allow(integration.client).to receive(:create_transaction).and_wrap_original do |original, model|
        credited = original.call(model)
      end

      provider.refund(order, return_items)

      # Asserted before reading it, so a swallowed refusal fails here rather than
      # blowing up on nil.
      expect(credited).to be_present
      expect(credited['lines'].map { |line| line['taxDate'] }).to all(eq('2024-01-15'))
    end

    it 'accepts a replayed credit', vcr: { cassette_name: 'refund/duplicate' } do
      provider.refund(order, return_items)

      expect { provider.refund(order, return_items) }.not_to raise_error
    end
  end

  describe 'address validation' do
    let(:service) { SpreeAvalara::Address::Validate.new }

    before { allow(SpreeAvalara::Integration).to receive(:active_for).and_return(integration) }

    it 'resolves a deliverable address', vcr: { cassette_name: 'address/resolved' } do
      address = build(:address, address1: '410 Terry Ave N', city: 'Seattle',
                                state_code: 'WA', country_code: 'US', zipcode: '98109')

      expect(service.call(address: address, store: @default_store)).to be_success
    end

    it 'refuses an address Avalara cannot place', vcr: { cassette_name: 'address/unresolved' } do
      address = build(:address, address1: 'Nowhere at all', city: 'Nowhere',
                                state_code: 'WA', country_code: 'US', zipcode: '00000')

      result = service.call(address: address, store: @default_store)

      expect(result).not_to be_success
      expect(result.error).not_to be_transport
    end
  end
end
