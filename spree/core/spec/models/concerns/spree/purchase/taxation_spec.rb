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

  describe '#tax_zone' do
    let(:zone) { create(:zone) }

    context 'when no zones exist' do
      it 'returns nil' do
        expect(record.tax_zone).to be_nil
      end
    end

    context 'when tax_using_ship_address: true' do
      before { Spree::Config.set(tax_using_ship_address: true) }

      it 'calculates using ship_address' do
        expect(Spree::Zone).to receive(:match).at_least(:once).with(ship_address)
        expect(Spree::Zone).not_to receive(:match).with(bill_address)
        record.tax_zone
      end
    end

    context 'when tax_using_ship_address: false' do
      before { Spree::Config.set(tax_using_ship_address: false) }

      it 'calculates using bill_address' do
        expect(Spree::Zone).to receive(:match).at_least(:once).with(bill_address)
        expect(Spree::Zone).not_to receive(:match).with(ship_address)
        record.tax_zone
      end
    end

    context 'when there is a default tax zone' do
      let!(:default_zone) { create(:zone, name: 'foo_zone') }

      before { allow(Spree::Zone).to receive_messages default_tax: default_zone }

      context 'when there is a matching zone' do
        before { allow(Spree::Zone).to receive_messages(match: zone) }

        it 'returns the matching zone' do
          expect(record.tax_zone).to eq(zone)
        end
      end

      context 'when there is no matching zone' do
        before { allow(Spree::Zone).to receive_messages(match: nil) }

        it 'returns the default tax zone' do
          expect(record.tax_zone).to eq(default_zone)
        end
      end
    end

    context 'when no default tax zone' do
      before { allow(Spree::Zone).to receive_messages default_tax: nil }

      context 'when there is a matching zone' do
        before { allow(Spree::Zone).to receive_messages(match: zone) }

        it 'returns the matching zone' do
          expect(record.tax_zone).to eq(zone)
        end
      end

      context 'when there is no matching zone' do
        before { allow(Spree::Zone).to receive_messages(match: nil) }

        it 'returns nil' do
          expect(record.tax_zone).to be_nil
        end
      end
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
