require 'spec_helper'

RSpec.describe Spree::Commissions::CalculateLine do
  subject(:calculate) { described_class }

  let(:store) { @default_store }
  let(:vendor) { create(:vendor, :approved, store: store) }
  let(:order) { create(:order, store: store, currency: 'USD') }
  let(:line_item) { create(:line_item, order: order, price: 100, quantity: 1) }
  let(:rate) { create(:commission_rate, store: store, kind: 'percentage', value: 10) }

  def call(**overrides)
    calculate.call(
      { rate: rate, vendor: vendor, order: order, line_item: line_item, commission_tax_rate: 0 }.merge(overrides)
    ).value
  end

  it 'charges a percentage of the item' do
    expect(call.amount).to eq(10)
  end

  it 'charges a percentage of every unit sold' do
    three = create(:line_item, order: order, price: 100, quantity: 3)

    expect(call(line_item: three).amount).to eq(30)
  end

  it 'charges a fixed rate once, however many units it covered' do
    three = create(:line_item, order: order, price: 100, quantity: 3)
    fixed = create(:commission_rate, :fixed, store: store, value: 2.5, currency: 'USD')

    expect(call(rate: fixed, line_item: three).amount).to eq(2.5)
  end

  it 'snapshots the rate that applied' do
    line = call

    expect(line.kind).to eq('percentage')
    expect(line.rate).to eq(10)
    expect(line.commission_rate).to eq(rate)
    expect(line.currency).to eq('USD')
  end

  describe 'the commission base' do
    # The EU rule: the fee is charged on what the seller earned net of the
    # consumer's VAT, because the fee is its own separate supply.
    it 'excludes VAT already inside the price' do
      line_item.update_columns(included_tax_total: 20)

      expect(call.amount).to eq(8)
    end

    it 'counts VAT added on top only when the rate asks for a gross base' do
      line_item.update_columns(additional_tax_total: 20)

      expect(call.amount).to eq(10)
      expect(call(rate: create(:commission_rate, :gross_base, store: store, value: 10)).amount).to eq(12)
    end

    it 'charges on what the customer actually paid, after discounts' do
      line_item.update_columns(taxable_adjustment_total: -40)

      expect(call.amount).to eq(6)
    end

    it 'never pays the seller a commission when a discount exceeds the item' do
      line_item.update_columns(taxable_adjustment_total: -500)

      expect(call.amount).to eq(0)
    end
  end

  describe 'floor and cap' do
    it 'lifts a commission to the floor' do
      floored = create(:commission_rate, store: store, value: 1, min_amount: 5)

      expect(call(rate: floored).amount).to eq(5)
    end

    it 'holds a commission to the cap' do
      capped = create(:commission_rate, store: store, value: 50, max_amount: 20)

      expect(call(rate: capped).amount).to eq(20)
    end
  end

  describe 'tax on the commission' do
    # The headline EU behaviour: VAT is charged on the marketplace's fee as a
    # separate B2B supply, on top of it rather than out of it.
    it 'adds tax on top of the fee and totals the two' do
      line = call(commission_tax_rate: 0.21)

      expect(line.amount).to eq(10)
      expect(line.tax_amount).to eq(2.1)
      expect(line.total).to eq(12.1)
    end

    it 'leaves the fee alone when nothing taxes it' do
      line = call(commission_tax_rate: 0)

      expect(line.tax_amount).to eq(0)
      expect(line.total).to eq(10)
    end

    it 'prefers an explicit rate override to anything the tax engine says' do
      overridden = create(:commission_rate, store: store, value: 10, commission_tax_rate: 0.19)
      # Stubbed on the class: the order builds a fresh provider per call, so
      # stubbing one returned instance would leave the real engine in play and
      # pass for the wrong reason.
      allow_any_instance_of(Spree::TaxProvider::Internal).to receive(:service_tax_rate).and_return(0.21)

      expect(call(rate: overridden, commission_tax_rate: nil).tax_amount).to eq(1.9)
    end

    it 'falls back to the store default when neither the rate nor the engine answers' do
      stub_store_preferences(store, default_commission_tax_rate: 0.2)
      allow_any_instance_of(Spree::TaxProvider::Internal).to receive(:service_tax_rate).and_return(nil)

      expect(call(commission_tax_rate: nil).tax_amount).to eq(2)
    end
  end

  describe 'rounding' do
    it 'rounds each part half-up to the currency, then sums them' do
      odd = create(:commission_rate, store: store, value: 3.33)
      line = call(rate: odd, commission_tax_rate: 0.21)

      # 100 * 3.33% = 3.33; 3.33 * 21% = 0.6993 -> 0.70
      expect(line.amount).to eq(3.33)
      expect(line.tax_amount).to eq(0.7)
      expect(line.total).to eq(4.03)
    end

    # A currency with no minor unit rounds to whole units, so a marketplace
    # billing in yen never writes a fraction of one.
    it 'follows the currency to its own minor unit' do
      allow_any_instance_of(Spree::Store).to receive(:supported_currencies_list).
        and_return([::Money::Currency.find('USD'), ::Money::Currency.find('JPY')])
      yen_order = create(:order, store: store, currency: 'JPY')
      yen_item = create(:line_item, order: yen_order, price: 1000, quantity: 1, currency: 'JPY')
      odd = create(:commission_rate, store: store, value: 3.33)

      line = call(rate: odd, order: yen_order, line_item: yen_item)

      expect(line.amount).to eq(33)
    end
  end

  it 'commissions a delivery when handed a fulfillment' do
    fulfillment = create(:fulfillment, order: order, cost: 50)

    line = call(line_item: nil, fulfillment: fulfillment)

    expect(line.amount).to eq(5)
    expect(line.fulfillment).to eq(fulfillment)
    expect(line.line_item).to be_nil
  end

  it 'refuses to price nothing' do
    expect(calculate.call(rate: rate, vendor: vendor, order: order)).to be_failure
  end

  # Both would silently commission the item and drop the delivery.
  it 'refuses to price an item and a delivery at once' do
    result = calculate.call(rate: rate, vendor: vendor, order: order,
                            line_item: line_item, fulfillment: create(:fulfillment, order: order))

    expect(result).to be_failure
  end
end
