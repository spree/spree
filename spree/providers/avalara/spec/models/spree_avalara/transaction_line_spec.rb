require 'spec_helper'

RSpec.describe SpreeAvalara::TransactionLine do
  # Deliberately small, hand-built payloads: this spec pins the code paths, not
  # what AvaTax actually sends. The shapes are Phase 7's question, and cassettes
  # settle them.
  def line(**overrides)
    {
      'lineNumber' => 'li_abc123',
      'lineAmount' => 100.0,
      'taxCalculated' => 8.25,
      'taxIncluded' => false,
      'exemptAmount' => 0.0,
      'exemptCertId' => 0,
      'exemptNo' => '',
      'entityUseCode' => '',
      'isItemTaxable' => true,
      'taxCode' => 'P0000000',
      'details' => [detail]
    }.merge(overrides)
  end

  def detail(**overrides)
    {
      'country' => 'US', 'region' => 'CA', 'taxName' => 'CA STATE TAX',
      'taxType' => 'Sales', 'rate' => 0.0625, 'taxCalculated' => 6.25,
      'nonTaxableAmount' => 0.0, 'rateTypeCode' => 'G'
    }.merge(overrides)
  end

  def build_line(payload_overrides = {}, context = {})
    described_class.new(payload: line(**payload_overrides), context: context)
  end

  let(:item) { build_stubbed(:line_item) }

  describe '.from_response' do
    it 'builds one line per response line and carries the request context' do
      body = { 'lines' => [line, line('lineNumber' => 'ful_xyz')] }

      lines = described_class.from_response(body, context: { ship_to_country: 'US' })

      expect(lines.map(&:line_number)).to eq(%w[li_abc123 ful_xyz])
      expect(lines.first.context).to eq(ship_to_country: 'US')
    end

    it 'has nothing to say about a response with no lines' do
      expect(described_class.from_response({}, context: {})).to eq([])
    end
  end

  describe '#matching_item' do
    it 'finds the item the line was sent as' do
      sent = build_line('lineNumber' => item.prefixed_id)

      expect(sent.matching_item([item])).to eq(item)
    end

    # A line we never sent means Avalara answered about something else; dropping
    # it silently would leave an item untaxed.
    it 'raises on a lineNumber that was never sent' do
      expect { build_line('lineNumber' => 'li_never_sent').matching_item([item]) }.
        to raise_error(SpreeAvalara::Error, /never sent/)
    end
  end

  describe '#to_tax_line_attributes' do
    let(:cart) { create(:cart, store: @default_store) }

    it 'writes a row core accepts, scoped to this provider' do
      attributes = build_line.to_tax_line_attributes(item: item, owner: cart)

      expect(attributes[:cart]).to eq(cart)
      expect(attributes[:line_item_id]).to eq(item.id)
      expect(attributes[:tax_rate_id]).to be_nil
      expect(attributes[:provider_id]).to eq('avalara')
      expect(attributes[:amount]).to eq(8.25)
      expect(attributes[:rate]).to eq(0.0625)
      expect(attributes[:label]).to eq('CA STATE TAX')
      expect(attributes[:included]).to be(false)
      expect(attributes[:country_code]).to eq('US')
      expect(attributes[:state_code]).to eq('CA')
      expect(attributes[:data]['avalara']['details']).to be_present
    end

    it 'keys an order owner as an order' do
      order = create(:order, store: @default_store)

      expect(build_line.to_tax_line_attributes(item: item, owner: order)).to include(order: order)
    end

    it 'refuses an item that is not taxable' do
      expect { build_line.to_tax_line_attributes(item: cart, owner: cart) }.
        to raise_error(SpreeAvalara::Error, /not taxable/)
    end

    # Avalara only ever sees OTHER/CUSTOM for a reason it does not define, so the
    # reason the merchant recorded has to survive on the row.
    it 'keeps the exemption reasons that were sent' do
      line = build_line({}, { exemption_reasons: ['SOMETHING_LOCAL'] })

      attributes = line.to_tax_line_attributes(item: item, owner: cart)

      expect(attributes[:data]['avalara']['sent_exemption_reasons']).to eq(['SOMETHING_LOCAL'])
    end

    it 'names every jurisdiction that taxed the line' do
      payload = { 'details' => [detail, detail('taxName' => 'LA COUNTY TAX', 'rate' => 0.01)] }

      attributes = build_line(payload).to_tax_line_attributes(item: item, owner: cart)

      expect(attributes[:label]).to eq('CA STATE TAX, LA COUNTY TAX')
      expect(attributes[:rate]).to eq(0.0725)
    end
  end

  describe '#taxability_reason' do
    def reason(payload_overrides = {}, context = {})
      build_line(payload_overrides, context).taxability_reason(item)
    end

    it 'is standard_rated when tax was charged' do
      expect(reason).to eq('standard_rated')
    end

    it 'is reduced_rated on a reduced VAT rate' do
      expect(reason('details' => [detail('rateTypeCode' => 'R')])).to eq('reduced_rated')
    end

    context 'customer exemptions' do
      let(:exempt) { { 'exemptAmount' => 100.0, 'taxCalculated' => 0.0 } }

      # Avalara echoes back the code it applied, so the line carries its own
      # evidence.
      it 'claims one when Avalara echoes the code that was sent' do
        expect(reason(exempt.merge('entityUseCode' => 'G'))).to eq('customer_exempt')
      end

      # A claim can cover some lines and not others, so an order-wide "something
      # was sent" is not evidence about this line.
      it 'does not claim one because another line was exempt' do
        no_nexus = exempt.merge(
          'details' => [detail('taxType' => 'Use', 'rate' => 0.0, 'taxCalculated' => 0.0,
                               'nonTaxableAmount' => 100.0)]
        )

        expect(reason(no_nexus, { exemption_sent: true })).to eq('not_collecting')
      end

      # Sending a code is not the same as Avalara honouring it: with no
      # certificate on file for the jurisdiction it taxes the line and can still
      # echo the code back. Reading that as an exemption would tell the merchant
      # tax was not collected on a line where it was.
      it 'claims none when the code came back but the line was taxed anyway' do
        expect(reason('entityUseCode' => 'G', 'exemptAmount' => 0.0)).to eq('standard_rated')
      end

      it 'claims one when Avalara applied its own certificate' do
        expect(reason(exempt.merge('exemptCertId' => 4321))).to eq('customer_exempt')
        expect(reason(exempt.merge('exemptNo' => 'EX-1'))).to eq('customer_exempt')
      end

      # The whole line lands in exemptAmount for a sale into a state with no
      # nexus. Calling that a customer exemption reports a certificate that does
      # not exist.
      it 'does not claim one from the exempt amount alone' do
        no_nexus = exempt.merge(
          'isItemTaxable' => false,
          'details' => [detail('taxType' => 'Use', 'rate' => 0.0, 'taxCalculated' => 0.0,
                               'nonTaxableAmount' => 100.0, 'taxName' => 'WA STATE TAX')]
        )

        expect(reason(no_nexus)).to eq('not_collecting')
      end
    end

    context 'zero tax' do
      it 'is not_collecting when the seller is not registered there' do
        payload = {
          'taxCalculated' => 0.0, 'exemptAmount' => 100.0, 'isItemTaxable' => false,
          'details' => [detail('taxType' => 'Use', 'rate' => 0.0, 'taxCalculated' => 0.0,
                               'nonTaxableAmount' => 100.0)]
        }

        expect(reason(payload)).to eq('not_collecting')
      end

      it 'is not_collecting when Avalara returns no jurisdictions at all' do
        expect(reason('taxCalculated' => 0.0, 'details' => [])).to eq('not_collecting')
      end

      # A registered out-of-state seller collects what some states call seller's
      # use tax. That is collected tax, not an absence of it.
      it 'is standard_rated when use tax was actually collected' do
        payload = {
          'taxCalculated' => 4.0,
          'details' => [detail('taxType' => 'Use', 'rate' => 0.04, 'taxCalculated' => 4.0)]
        }

        expect(reason(payload)).to eq('standard_rated')
      end

      # Tax applies in this jurisdiction, just not to this line.
      it 'is product_exempt when the rate is real but the line is not taxable' do
        payload = {
          'taxCalculated' => 0.0, 'exemptAmount' => 100.0, 'isItemTaxable' => false,
          'details' => [detail('nonTaxableAmount' => 100.0)]
        }

        expect(reason(payload)).to eq('product_exempt')
      end

      it 'is not_subject_to_tax when the jurisdiction levies no such tax' do
        payload = {
          'taxCalculated' => 0.0,
          'details' => [detail('rate' => 0.0, 'taxCalculated' => 0.0, 'nonTaxableType' => 'RateRule')]
        }

        expect(reason(payload)).to eq('not_subject_to_tax')
      end

      it 'is export when Avalara marks the supply as one' do
        payload = {
          'taxCalculated' => 0.0,
          'details' => [detail('rate' => 0.0, 'nonTaxableType' => 'Export')]
        }

        expect(reason(payload)).to eq('export')
      end

      it 'falls back to zero_rated' do
        payload = { 'taxCalculated' => 0.0, 'details' => [detail('rate' => 0.0, 'taxCalculated' => 0.0)] }

        expect(reason(payload)).to eq('zero_rated')
      end
    end

    context 'the EU split, which Avalara reports as a zero rate either way' do
      let(:zero_vat) do
        { 'taxCalculated' => 0.0, 'vatCode' => 'EU',
          'details' => [detail('country' => 'DE', 'region' => nil, 'rate' => 0.0,
                               'taxCalculated' => 0.0, 'rateTypeCode' => 'Z')] }
      end

      it 'is intra_community_supply for goods crossing an internal border' do
        context = { identifier_sent: true, ship_from_country: 'DE', ship_to_country: 'FR' }

        expect(reason(zero_vat, context)).to eq('intra_community_supply')
      end

      # A cross-border supply that is not goods: the service case the EU
      # reverse-charges.
      it 'is reverse_charge for a cross-border service to a registered buyer' do
        context = { identifier_sent: true, ship_from_country: 'DE', ship_to_country: 'FR' }
        fee = build_stubbed(:fee)

        expect(build_line(zero_vat, context).taxability_reason(fee)).to eq('reverse_charge')
      end

      # Books and food are zero-rated everywhere they are sold, and a buyer who
      # happens to hold a registration does not turn that into reverse charge —
      # they are different e-invoice categories.
      it 'leaves a domestic zero-rated sale alone' do
        context = { identifier_sent: true, ship_from_country: 'DE', ship_to_country: 'DE' }

        expect(reason(zero_vat, context)).to eq('zero_rated')
      end

      it 'is neither without a buyer registration' do
        context = { ship_from_country: 'DE', ship_to_country: 'FR' }

        expect(reason(zero_vat, context)).to eq('zero_rated')
      end

      # An order allocated across warehouses in different countries has no one
      # origin, and the request already sends a shipFrom per line. Reading the
      # owner's origin for every line calls a domestic sale an intra-community
      # supply, or the reverse.
      describe 'when the order ships from more than one country' do
        it "reads the line's own origin rather than the order's" do
          context = { identifier_sent: true, ship_from_country: 'DE', ship_to_country: 'FR',
                      ship_from_countries: { 'li_abc123' => 'FR' } }

          expect(reason(zero_vat, context)).to eq('zero_rated')
        end

        it 'still crosses a border for a line shipped from elsewhere' do
          context = { identifier_sent: true, ship_from_country: 'FR', ship_to_country: 'FR',
                      ship_from_countries: { 'li_abc123' => 'DE' } }

          expect(reason(zero_vat, context)).to eq('intra_community_supply')
        end

        it "falls back to the order's origin for a line it was not given" do
          context = { identifier_sent: true, ship_from_country: 'DE', ship_to_country: 'FR',
                      ship_from_countries: { 'li_elsewhere' => 'FR' } }

          expect(reason(zero_vat, context)).to eq('intra_community_supply')
        end
      end
    end

    it 'only produces reasons core accepts' do
      expect(Spree::TaxLine.taxability_reasons).to include(reason)
    end
  end
end
