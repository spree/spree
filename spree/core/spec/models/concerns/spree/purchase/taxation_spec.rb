require 'spec_helper'

RSpec.shared_examples 'a taxation host' do
  let(:store) { @default_store }
  let(:bill_address) { create(:address) }
  let(:ship_address) { create(:address) }

  describe '#tax_address' do
    it 'uses the ship address when the store prefers it' do
      stub_store_preferences(store, tax_using_ship_address: true)
      expect(record.tax_address).to eq(ship_address)
    end

    it 'uses the bill address when the store prefers it' do
      stub_store_preferences(store, tax_using_ship_address: false)
      expect(record.tax_address).to eq(bill_address)
    end
  end

  describe '#tax_total' do
    it 'sums included and additional tax' do
      record.included_tax_total = 5
      record.additional_tax_total = 3

      expect(record.tax_total).to eq(8)
    end
  end

  describe '#resolved_tax_identifier' do
    let(:customer) { create(:user) }

    before { record.update!(customer: customer) }

    it 'treats a buyer with no registration as a consumer' do
      expect(record.resolved_tax_identifier).to be_nil
    end

    it 'falls back to the customer registration' do
      identifier = create(:tax_identifier, owner: customer)

      expect(record.resolved_tax_identifier).to eq(identifier)
    end

    it 'prefers a verified registration over a newer unverified one' do
      verified = create(:tax_identifier, :verified, owner: customer, kind: 'eu_vat')
      create(:tax_identifier, owner: customer, kind: 'gb_vat')

      expect(record.resolved_tax_identifier).to eq(verified)
    end

    context 'when the sale is for a business' do
      let(:company) { create(:company, store: store) }
      # The purchase points at a division; the registration resolves through
      # its legal entity — the parent company node.
      let(:division) { create(:company, store: store, kind: 'division', parent: company) }

      before do
        create(:company_membership, company: division, customer: customer)
        record.update!(company: division)
      end

      # The invoice is addressed to the entity, so its registration wins.
      it 'prefers the company registration over the buyer own' do
        create(:tax_identifier, owner: customer, kind: 'eu_vat')
        company_identifier = create(:tax_identifier, owner: company, kind: 'eu_vat')

        expect(record.resolved_tax_identifier).to eq(company_identifier)
      end

      it 'still falls back to the buyer when the company has none' do
        identifier = create(:tax_identifier, owner: customer)

        expect(record.resolved_tax_identifier).to eq(identifier)
      end

      it 'prefers a verified company registration' do
        verified = create(:tax_identifier, :verified, owner: company, kind: 'eu_vat')
        create(:tax_identifier, owner: company, kind: 'gb_vat')

        expect(record.resolved_tax_identifier).to eq(verified)
      end
    end

    it 'prefers the record own override over the customer registration' do
      create(:tax_identifier, owner: customer)
      override = create(:tax_identifier, kind: 'eu_vat', owner: record)

      expect(record.resolved_tax_identifier).to eq(override)
    end
  end

  describe '#tax_estimate_inputs' do
    let(:customer) { create(:user) }

    before { record.update!(customer: customer) }

    it 'carries the effective date, the buyer registration and the exemptions' do
      identifier = create(:tax_identifier, owner: customer)
      exemption = Spree::TaxExemption.new(reason_code: 'resale')
      allow(Spree.tax_resolve_exemptions_service).to receive(:new).
        and_return(instance_double(Spree::Tax::ResolveExemptions,
                                   call: Spree::ServiceModule::Result.new(true, [exemption], nil)))

      inputs = record.tax_estimate_inputs

      expect(inputs[:tax_date]).to be_present
      expect(inputs[:tax_identifier]).to eq(identifier)
      expect(inputs[:exemptions]).to eq([exemption])
    end

    # The resolver is swappable, so a host's handler can hand core an entry the
    # provider would read as "the whole order is exempt". Charging tax is the
    # safe direction, so it is dropped and reported rather than passed on.
    it 'drops an exemption whose overrides cannot name their line' do
      unusable = Spree::TaxExemption.new(
        reason_code: 'resale',
        item_overrides: [Spree::TaxExemption::ItemOverride.new(exempt: false)]
      )
      allow(Spree.tax_resolve_exemptions_service).to receive(:new).
        and_return(instance_double(Spree::Tax::ResolveExemptions,
                                   call: Spree::ServiceModule::Result.new(true, [unusable], nil)))
      allow(Rails.error).to receive(:report)

      expect(record.tax_estimate_inputs[:exemptions]).to be_empty
      expect(Rails.error).to have_received(:report).
        with(instance_of(Spree::Tax::UnusableExemptionError), hash_including(handled: true))
    end

    it 'keeps a usable one alongside it' do
      usable = Spree::TaxExemption.new(reason_code: 'resale')
      unusable = Spree::TaxExemption.new(
        reason_code: 'government',
        item_overrides: [Spree::TaxExemption::ItemOverride.new(exempt: false)]
      )
      allow(Spree.tax_resolve_exemptions_service).to receive(:new).
        and_return(instance_double(Spree::Tax::ResolveExemptions,
                                   call: Spree::ServiceModule::Result.new(true, [usable, unusable], nil)))
      allow(Rails.error).to receive(:report)

      expect(record.tax_estimate_inputs[:exemptions]).to eq([usable])
    end

    it 'is accepted whole by the provider contract' do
      expect { Spree::TaxProvider::Internal.new.estimate(record, [], **record.tax_estimate_inputs) }.
        not_to raise_error
    end
  end

  describe '#pre_tax_item_amount / #pre_tax_total' do
    it 'sums line item and fulfillment pre-tax amounts' do
      create(:line_item, record.is_a?(Spree::Cart) ? { cart: record, order: nil } : { order: record }).update_column(:pre_tax_amount, 7)

      expect(record.pre_tax_item_amount).to eq(7)
      expect(record.pre_tax_total).to eq(7)
    end
  end

  describe '#taxable_items' do
    # Both hosts own fees through the exactly-one owner FK, so the factory
    # needs the matching key.
    def owner_attributes
      record.is_a?(Spree::Cart) ? { cart: record, order: nil } : { order: record }
    end

    it 'withholds customs duties while keeping every other fee' do
      create(:fee, owner_attributes.merge(amount: 20, kind: 'duty', label: 'Import duty'))
      surcharge = create(:fee, owner_attributes.merge(amount: 5, kind: 'surcharge', label: 'Handling'))

      expect(record.taxable_items.grep(Spree::Fee)).to contain_exactly(surcharge)
    end

    # The associations load empty at record creation, and recalculation asks
    # for taxable items right after adjusters have written fees — so this must
    # read fresh, not from the cache, on both hosts.
    it 'sees fees written after the association was first loaded' do
      record.fees.load

      late = create(:fee, owner_attributes.merge(amount: 5, kind: 'handling', label: 'Late fee'))

      expect(record.taxable_items).to include(late)
    end
  end
end

RSpec.describe Spree::Purchase::Taxation do
  context 'included in Spree::Cart' do
    let(:record) { create(:cart, store: store, ship_address: ship_address, bill_address: bill_address) }

    it_behaves_like 'a taxation host'
  end

  context 'included in Spree::Order' do
    let(:record) { create(:order, store: store, ship_address: ship_address, bill_address: bill_address) }

    it_behaves_like 'a taxation host'

    describe '#resolved_tax_identifier on a placed order' do
      let(:customer) { create(:user) }
      let(:record) { create(:completed_order_with_totals, customer: customer) }

      it 'reads its own snapshot and never re-resolves' do
        create(:tax_identifier, owner: customer)

        expect(record.resolved_tax_identifier).to be_nil

        snapshot = create(:tax_identifier, :on_order, owner: record)
        expect(record.reload.resolved_tax_identifier).to eq(snapshot)
      end
    end

    # A certificate lapses on its own date with nothing written to it, so a
    # credit filed months later must read what the sale was priced with rather
    # than what resolves on the day.
    describe '#usable_exemptions on a placed order' do
      let(:record) { create(:completed_order_with_totals) }

      # A resolver answering something the snapshot never contains, so which
      # source was read is visible in the result rather than in a call count —
      # completing an order resolves exemptions of its own accord.
      before do
        live = Spree::TaxExemption.new(reason_code: 'resolved_live')
        allow(Spree).to receive(:tax_resolve_exemptions_service).and_return(
          class_double(Spree::Tax::ResolveExemptions,
                       new: instance_double(Spree::Tax::ResolveExemptions, call: double(value: [live])))
        )
      end

      it 'answers from its frozen claims instead of resolving again' do
        record.update_column(:applied_tax_exemptions,
                             [{ 'reason_code' => 'resale', 'certificate_number' => 'CERT-1',
                                'country_code' => 'US', 'state_code' => 'CA', 'item_overrides' => [] }])

        claim = record.reload.usable_exemptions.sole

        expect(claim).to be_a(Spree::TaxExemption)
        expect(claim.reason_code).to eq('resale')
        expect(claim.certificate_number).to eq('CERT-1')
        expect(claim.covers_jurisdiction?('US', 'CA')).to be(true)
        expect(claim.covers_jurisdiction?('US', 'NY')).to be(false)
      end

      it 'rebuilds the per-line carve-outs a claim was narrowed by' do
        line_item = record.line_items.first
        record.update_column(:applied_tax_exemptions,
                             [{ 'reason_code' => 'resale', 'item_overrides' => [
                               { 'item_id' => line_item.prefixed_id, 'exempt' => false, 'reason_code' => nil }
                             ] }])

        claim = record.reload.usable_exemptions.sole

        expect(claim.covers_item?(line_item)).to be(false)
      end

      # An empty snapshot records "found no claim", not an absence. Read as
      # absent, a certificate added later would explain a sale it never touched.
      it 'keeps answering nothing when it froze nothing' do
        record.update_column(:applied_tax_exemptions, [])

        expect(record.reload.usable_exemptions).to eq([])
      end

      # Only nil is the legacy state — orders placed before the column existed.
      it 'resolves live only when it holds no snapshot at all' do
        expect(record.applied_tax_exemptions).to be_nil
        expect(record.usable_exemptions.map(&:reason_code)).to eq(['resolved_live'])
      end
    end
  end
end
