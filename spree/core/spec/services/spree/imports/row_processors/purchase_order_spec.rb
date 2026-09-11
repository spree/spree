require 'spec_helper'

RSpec.describe Spree::Imports::RowProcessors::PurchaseOrder, type: :service do
  let(:store) { @default_store }
  let(:import) { create(:purchase_orders_import, store: store) }
  let(:csv_row_headers) { Spree::ImportSchemas::PurchaseOrders.new.headers }

  let!(:supplier) { create(:supplier, store: store, name: 'Acme Wholesale') }
  let!(:destination) { create(:stock_location, store: store, name: 'Brooklyn') }
  let(:product) { create(:product, store: store) }
  let!(:variant) { create(:variant, product: product, sku: 'DENIM-M') }
  let!(:other_variant) { create(:variant, product: product, sku: 'DENIM-L') }

  before do
    Spree.import_start_mapping_workflow.call(import: import)
  end

  def csv_row_hash(attrs = {})
    csv_row_headers.index_with { |header| attrs[header] }
  end

  def process(attrs)
    row = create(:import_row, import: import, data: csv_row_hash(attrs).to_json)
    described_class.new(row).process!
  end

  let(:line) do
    { 'reference' => 'ACME-0042', 'supplier' => 'acme wholesale', 'destination' => 'Brooklyn',
      'sku' => 'DENIM-M', 'quantity' => '24', 'unit_cost' => '12.50' }
  end

  it 'opens a draft order for the row through the same workflow the screen uses' do
    purchase_order = process(line.merge('currency' => 'usd', 'expected_at' => '2026-10-01',
                                        'cancel_by' => '2026-10-15', 'notes' => 'Autumn buy'))

    expect(purchase_order).to be_a(Spree::PurchaseOrder)
    expect(purchase_order).to be_draft
    expect(purchase_order).to have_attributes(
      supplier: supplier, destination_location: destination, reference: 'ACME-0042', currency: 'USD',
      expected_at: Date.new(2026, 10, 1), cancel_by: Date.new(2026, 10, 15), notes: 'Autumn buy'
    )
    expect(purchase_order.created_by).to eq(import.user)
    expect(purchase_order.items.sole).to have_attributes(variant: variant, quantity_ordered: 24, unit_cost: 12.5)
  end

  it 'adds later rows with the same reference to that order, totalling a repeated SKU' do
    first = process(line)
    process(line.merge('sku' => 'DENIM-L', 'quantity' => '6', 'unit_cost' => '13.00'))
    second = process(line.merge('quantity' => '12'))

    expect(second).to eq(first)
    expect(Spree::PurchaseOrder.count).to eq(1)
    lines = first.reload.items.map { |item| [item.variant.sku, item.quantity_ordered, item.unit_cost] }
    expect(lines).to contain_exactly(['DENIM-M', 36, 12.5], ['DENIM-L', 6, 13.0])
  end

  it 'opens a separate order for each reference' do
    process(line)
    process(line.merge('reference' => 'ACME-0043'))

    expect(Spree::PurchaseOrder.pluck(:reference)).to contain_exactly('ACME-0042', 'ACME-0043')
  end

  it 'names suppliers and warehouses rather than creating them' do
    expect { process(line.merge('supplier' => 'Nobody')) }.
      to raise_error(ArgumentError, Spree.t(:purchase_order_import_unknown_supplier, name: 'Nobody'))
    expect { process(line.merge('destination' => 'Mars')) }.
      to raise_error(ArgumentError, Spree.t(:purchase_order_import_unknown_destination, name: 'Mars'))
    expect(Spree::Supplier.count).to eq(1)
    expect(Spree::PurchaseOrder.count).to eq(0)
  end

  it 'needs the SKU to exist, once' do
    expect { process(line.merge('sku' => 'NOPE')) }.
      to raise_error(ArgumentError, Spree.t(:purchase_order_import_unknown_sku, sku: 'NOPE'))

    # Past the SKU validation, the way a legacy catalogue can be.
    create(:variant, product: create(:product, store: store)).update_columns(sku: 'denim-m')
    expect { process(line) }.
      to raise_error(ArgumentError, Spree.t(:purchase_order_import_ambiguous_sku, sku: 'DENIM-M'))
  end

  it 'refuses a reference-less row, since nothing could group it' do
    expect { process(line.merge('reference' => ' ')) }.
      to raise_error(ArgumentError, Spree.t(:purchase_order_import_reference_required))
  end

  it 'refuses quantities, costs, currencies and dates it cannot read' do
    expect { process(line.merge('quantity' => '0')) }.
      to raise_error(ArgumentError, Spree.t(:purchase_order_import_invalid_quantity, value: '0'))
    expect { process(line.merge('quantity' => 'ten')) }.
      to raise_error(ArgumentError, Spree.t(:purchase_order_import_invalid_quantity, value: 'ten'))
    expect { process(line.merge('unit_cost' => '')) }.
      to raise_error(ArgumentError, Spree.t(:purchase_order_import_invalid_cost, value: ''))
    expect { process(line.merge('currency' => 'XXX')) }.
      to raise_error(ArgumentError, Spree.t(:purchase_order_import_unsupported_currency, currency: 'XXX'))
    expect { process(line.merge('expected_at' => 'March')) }.
      to raise_error(ArgumentError, Spree.t(:purchase_order_import_invalid_date, column: 'expected_at', value: 'March'))
  end
end
