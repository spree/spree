require 'spec_helper'

RSpec.describe Spree::Exports::PurchaseOrders, type: :model do
  let(:store) { @default_store }
  let(:user) { create(:admin_user) }
  let(:supplier) { create(:supplier, store: store, name: 'Acme Wholesale') }
  let(:destination) { create(:stock_location, store: store, name: 'Brooklyn') }
  let(:product) { create(:product, name: 'Denim Shirt', store: store) }
  let(:variant) { create(:variant, product: product, sku: 'DENIM-M') }

  let!(:purchase_order) do
    create(:purchase_order, store: store, supplier: supplier, destination_location: destination, quantity: 0).tap do |order|
      order.items.create!(variant: variant, quantity_ordered: 24, quantity_received: 20, quantity_rejected: 2, unit_cost: 12.5)
      order.update!(reference: 'ACME-0042', expected_at: Date.new(2026, 10, 1), cancel_by: Date.new(2026, 10, 15))
    end
  end

  def build_export(search_params: nil, record_selection: 'all')
    described_class.new(store: store, user: user, search_params: search_params, record_selection: record_selection)
  end

  describe '#generate_csv' do
    it 'writes one row per line with the order alongside, importable as it stands' do
      export = build_export
      export.save!
      export.generate

      rows = CSV.parse(export.attachment.download, headers: true)
      expect(rows.headers).to eq(Spree::CSV::PurchaseOrderItemPresenter::HEADERS)
      expect(rows.headers).to include(*Spree::ImportSchemas::PurchaseOrders.new.headers)

      row = rows.sole.to_h
      expect(row).to include(
        'reference' => 'ACME-0042', 'supplier' => 'Acme Wholesale', 'destination' => 'Brooklyn',
        'sku' => 'DENIM-M', 'quantity' => '24', 'unit_cost' => '12.50', 'currency' => store.default_currency,
        'expected_at' => '2026-10-01', 'cancel_by' => '2026-10-15',
        'number' => purchase_order.number, 'status' => 'draft', 'product_name' => 'Denim Shirt',
        'received' => '20', 'rejected' => '2'
      )
    end

    it 'writes every line of an order as its own row, under the same number' do
      other_variant = create(:variant, product: product, sku: 'DENIM-L')
      purchase_order.items.create!(variant: other_variant, quantity_ordered: 6, unit_cost: 13)

      export = build_export
      export.save!
      export.generate

      rows = CSV.parse(export.attachment.download, headers: true)
      expect(rows.map { |row| row.values_at('number', 'sku', 'quantity') }).to contain_exactly(
        [purchase_order.number, 'DENIM-M', '24'],
        [purchase_order.number, 'DENIM-L', '6']
      )
    end

    it 'narrows to the orders a filter names' do
      other = create(:purchase_order, store: store)

      export = build_export(search_params: { number_eq: other.number }, record_selection: 'filtered')
      export.save!
      export.generate

      rows = CSV.parse(export.attachment.download, headers: true)
      expect(rows.map { |row| row['number'] }).to eq([other.number])
    end
  end

  it 'is gated by the purchasing scope, like the purchase order endpoints' do
    expect(described_class.required_scope).to eq(:purchasing)
    expect(described_class.model_class).to eq(Spree::PurchaseOrder)
  end
end
