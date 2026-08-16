require 'spec_helper'

RSpec.describe Spree::Commissions::CommissionOrder do
  let(:store) { @default_store }
  let(:vendor) { create(:vendor, :approved, store: store) }
  let(:other_vendor) { create(:vendor, :approved, store: store) }
  let(:order) { create(:order, store: store, currency: 'USD') }

  let!(:rate) { create(:commission_rate, store: store, kind: 'percentage', value: 10) }

  def line_for(seller, price: 100)
    product = create(:product, store: store, vendor: seller)
    create(:line_item, order: order, variant: product.default_variant, price: price, quantity: 1)
  end

  def commission
    described_class.call(order: order).value
  end

  it 'charges the seller of each item sold' do
    line = line_for(vendor)

    lines = commission

    expect(lines.size).to eq(1)
    expect(lines.first).to have_attributes(vendor: vendor, line_item: line, amount: 10, order: order)
  end

  it 'leaves the marketplace own items alone' do
    create(:line_item, order: order, price: 100, quantity: 1)

    expect(commission).to be_empty
  end

  it 'charges each seller on a mixed order separately' do
    line_for(vendor, price: 100)
    line_for(other_vendor, price: 50)

    lines = commission

    expect(lines.map(&:vendor)).to match_array([vendor, other_vendor])
    expect(lines.find { |l| l.vendor == vendor }.amount).to eq(10)
    expect(lines.find { |l| l.vendor == other_vendor }.amount).to eq(5)
  end

  # A commission line is a settlement record: charging twice for one sale is
  # the failure that matters most here.
  it 'does not charge again for an order it already commissioned' do
    line_for(vendor)

    commission

    expect { commission }.not_to change(Spree::CommissionLine, :count)
  end

  it 'writes nothing when no rate matches the sale' do
    rate.update!(enabled: false)
    line_for(vendor)

    expect(commission).to be_empty
  end

  it 'never touches what the customer pays' do
    line_for(vendor)
    total_before = order.reload.total

    commission

    expect(order.reload.total).to eq(total_before)
    expect(order.fees).to be_empty
  end

  describe 'delivery' do
    let!(:rate) { create(:commission_rate, :with_shipping, store: store, kind: 'percentage', value: 10) }

    # The factory fills a fulfillment from every line on the order, so carrying
    # exactly the named lines has to be stated.
    def fulfillment_carrying(*line_items, cost: 20)
      fulfillment = create(:fulfillment, order: order, cost: cost)
      fulfillment.fulfillment_items.destroy_all
      line_items.each { |line_item| fulfillment.fulfillment_items.create!(line_item: line_item, quantity: 1) }
      fulfillment
    end

    it 'charges the delivery when the rate includes shipping' do
      fulfillment_carrying(line_for(vendor))

      delivery_line = commission.find(&:fulfillment_id)

      expect(delivery_line.amount).to eq(2)
      expect(delivery_line.vendor).to eq(vendor)
    end

    it 'leaves delivery alone when the rate does not include shipping' do
      rate.update!(include_shipping: false)
      fulfillment_carrying(line_for(vendor))

      expect(commission.select(&:fulfillment_id)).to be_empty
    end

    it 'charges a delivery only to the seller whose goods it carries' do
      mine = line_for(vendor)
      theirs = line_for(other_vendor)
      fulfillment_carrying(mine)
      fulfillment_carrying(theirs, cost: 0)

      delivery_lines = commission.select(&:fulfillment_id)

      expect(delivery_lines.map(&:vendor)).to eq([vendor])
    end

    # Before the split, one delivery can carry two sellers' goods. It belongs
    # to neither alone: billing both charges one parcel twice, and picking one
    # bills the wrong seller.
    it 'leaves a delivery shared between sellers uncommissioned' do
      fulfillment_carrying(line_for(vendor), line_for(other_vendor))

      lines = commission

      expect(lines.select(&:fulfillment_id)).to be_empty
      expect(lines.select(&:line_item_id).size).to eq(2)
    end

    it 'charges nothing for a free delivery' do
      fulfillment_carrying(line_for(vendor), cost: 0)

      expect(commission.select(&:fulfillment_id)).to be_empty
    end
  end

  describe 'tax on the commission' do
    # Each rate may carry its own tax override, so a basket governed by two
    # rates must not have the first one's answer applied to both.
    it 'taxes each line by the rate that governed it' do
      generic = line_for(vendor, price: 100)
      special_product = create(:product, store: store, vendor: vendor)
      special_line = create(:line_item, order: order, variant: special_product.default_variant,
                                        price: 100, quantity: 1)

      special_rate = create(:commission_rate, store: store, value: 10, priority: 10,
                                              commission_tax_rate: 0.19)
      create(:commission_rule, commission_rate: special_rate, subject: special_product)
      rate.update!(commission_tax_rate: 0.05)

      lines = commission.index_by(&:line_item_id)

      expect(lines[special_line.id].tax_amount).to eq(1.9)
      expect(lines[generic.id].tax_amount).to eq(0.5)
    end

    # One rate governing a whole basket is one question about where the seller
    # sits, so the tax engine is consulted once rather than per item.
    it 'asks the tax engine once for a basket governed by one rate' do
      3.times { line_for(vendor) }
      asked = 0
      allow_any_instance_of(Spree::TaxProvider::Internal).to receive(:service_tax_rate) do
        asked += 1
        0.2
      end

      lines = commission

      expect(lines.size).to eq(3)
      expect(asked).to eq(1)
    end
  end

  describe 'the seller it charges' do
    # The line's own snapshot is the record of who sold it — the catalog
    # changing hands afterwards must never move the charge.
    it 'follows the line snapshot rather than the product today' do
      line = line_for(vendor)
      line.variant.product.update!(vendor: other_vendor)

      expect(commission.first.vendor).to eq(vendor)
    end
  end
end
