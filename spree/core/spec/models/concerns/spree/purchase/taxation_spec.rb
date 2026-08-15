require 'spec_helper'

RSpec.shared_examples 'a taxation host' do
  let(:store) { @default_store }
  let(:bill_address) { create(:address) }
  let(:ship_address) { create(:address) }

  describe '#tax_address' do
    it 'honors the tax_using_ship_address preference' do
      Spree::Config.set(tax_using_ship_address: true)
      expect(record.tax_address).to eq(ship_address)

      Spree::Config.set(tax_using_ship_address: false)
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
      identifier = create(:tax_identifier, customer: customer)

      expect(record.resolved_tax_identifier).to eq(identifier)
    end

    it 'prefers a verified registration over a newer unverified one' do
      verified = create(:tax_identifier, :verified, customer: customer, kind: 'eu_vat')
      create(:tax_identifier, customer: customer, kind: 'gb_vat')

      expect(record.resolved_tax_identifier).to eq(verified)
    end

    context 'when the sale is for a business' do
      let(:company) { create(:company, store: store) }
      let(:location) { create(:company_location, company: company) }

      before { record.update!(company_location: location) }

      # The invoice is addressed to the entity, so its registration wins.
      it 'prefers the company registration over the buyer own' do
        create(:tax_identifier, customer: customer, kind: 'eu_vat', value: 'DE111111111')
        company_identifier = create(:tax_identifier, customer: nil, company: company,
                                                     kind: 'eu_vat', value: 'DE222222222')

        expect(record.resolved_tax_identifier).to eq(company_identifier)
      end

      it 'still falls back to the buyer when the company has none' do
        identifier = create(:tax_identifier, customer: customer)

        expect(record.resolved_tax_identifier).to eq(identifier)
      end

      it 'prefers a verified company registration' do
        verified = create(:tax_identifier, :verified, customer: nil, company: company, kind: 'eu_vat')
        create(:tax_identifier, customer: nil, company: company, kind: 'gb_vat')

        expect(record.resolved_tax_identifier).to eq(verified)
      end
    end

    it 'prefers the record own override over the customer registration' do
      create(:tax_identifier, customer: customer)
      owner_key = record.is_a?(Spree::Cart) ? :cart : :order
      override = create(:tax_identifier, { customer: nil, kind: 'eu_vat', value: 'DE555555555', owner_key => record })

      expect(record.resolved_tax_identifier).to eq(override)
    end
  end

  describe '#tax_estimate_inputs' do
    let(:customer) { create(:user) }

    before { record.update!(customer: customer) }

    it 'carries the effective date, the buyer registration and the exemptions' do
      identifier = create(:tax_identifier, customer: customer)
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
        create(:tax_identifier, customer: customer)

        expect(record.resolved_tax_identifier).to be_nil

        snapshot = create(:tax_identifier, :on_order, order: record)
        expect(record.reload.resolved_tax_identifier).to eq(snapshot)
      end
    end
  end
end
