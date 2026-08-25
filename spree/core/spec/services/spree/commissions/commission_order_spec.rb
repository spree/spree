require 'spec_helper'

RSpec.describe Spree::Commissions::CommissionOrder do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }
  let(:other_seller) { create(:seller, :approved, store: store) }
  let(:order) { create(:order, store: store, currency: 'USD') }

  let!(:rate) { create(:commission_rate, store: store, kind: 'percentage', value: 10) }

  def line_for(seller, price: 100)
    product = create(:product, store: store, seller: seller)
    create(:line_item, order: order, variant: product.default_variant, price: price, quantity: 1)
  end

  def commission
    described_class.call(order: order).value
  end

  it 'charges the seller of each item sold' do
    line = line_for(seller)

    lines = commission

    expect(lines.size).to eq(1)
    expect(lines.first).to have_attributes(seller: seller, line_item: line, amount: 10, order: order)
  end

  it 'leaves the marketplace own items alone' do
    create(:line_item, order: order, price: 100, quantity: 1)

    expect(commission).to be_empty
  end

  it 'charges each seller on a mixed order separately' do
    line_for(seller, price: 100)
    line_for(other_seller, price: 50)

    lines = commission

    expect(lines.map(&:seller)).to match_array([seller, other_seller])
    expect(lines.find { |l| l.seller == seller }.amount).to eq(10)
    expect(lines.find { |l| l.seller == other_seller }.amount).to eq(5)
  end

  # A commission line is a settlement record: charging twice for one sale is
  # the failure that matters most here.
  it 'does not charge again for an order it already commissioned' do
    line_for(seller)

    commission

    expect { commission }.not_to change(Spree::CommissionLine, :count)
  end

  # Two deliveries of the same event race: the unique index stops the second
  # writing, and the loser reports the winner's lines rather than failing a
  # checkout over work already done.
  it 'reports the existing lines when another delivery got there first' do
    line_for(seller)
    # Stands in for the winner committing between this caller's guard and its
    # own write — the index raises, and the loser has to recover from it
    # rather than failing the checkout.
    allow_any_instance_of(Spree::CommissionLine).to receive(:save!).
      and_raise(ActiveRecord::RecordNotUnique, 'duplicate')

    result = described_class.call(order: order)

    expect(result).to be_success
    expect(result.value).to eq([])
  end

  it 'writes nothing when no rate matches the sale' do
    rate.update!(enabled: false)
    line_for(seller)

    expect(commission).to be_empty
  end

  it 'never touches what the customer pays' do
    line_for(seller)
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
      line_items.each do |line_item|
        fulfillment.fulfillment_items.create!(line_item: line_item, variant: line_item.variant, quantity: 1)
      end
      fulfillment
    end

    it 'charges the delivery when the rate includes shipping' do
      fulfillment_carrying(line_for(seller))

      delivery_line = commission.find(&:fulfillment_id)

      expect(delivery_line.amount).to eq(2)
      expect(delivery_line.seller).to eq(seller)
    end

    it 'leaves delivery alone when the rate does not include shipping' do
      rate.update!(include_shipping: false)
      fulfillment_carrying(line_for(seller))

      expect(commission.select(&:fulfillment_id)).to be_empty
    end

    it 'charges a delivery only to the seller whose goods it carries' do
      mine = line_for(seller)
      theirs = line_for(other_seller)
      fulfillment_carrying(mine)
      fulfillment_carrying(theirs, cost: 0)

      delivery_lines = commission.select(&:fulfillment_id)

      expect(delivery_lines.map(&:seller)).to eq([seller])
    end

    # Before the split, one delivery can carry two sellers' goods. It belongs
    # to neither alone: billing both charges one parcel twice, and picking one
    # bills the wrong seller.
    it 'leaves a delivery shared between sellers uncommissioned' do
      fulfillment_carrying(line_for(seller), line_for(other_seller))

      lines = commission

      expect(lines.select(&:fulfillment_id)).to be_empty
      expect(lines.select(&:line_item_id).size).to eq(2)
    end

    it 'charges nothing for a free delivery' do
      fulfillment_carrying(line_for(seller), cost: 0)

      expect(commission.select(&:fulfillment_id)).to be_empty
    end
  end

  describe 'tax on the commission' do
    # Each rate may carry its own tax override, so a basket governed by two
    # rates must not have the first one's answer applied to both.
    it 'taxes each line by the rate that governed it' do
      generic = line_for(seller, price: 100)
      special_product = create(:product, store: store, seller: seller)
      special_line = create(:line_item, order: order, variant: special_product.default_variant,
                                        price: 100, quantity: 1)

      # Created after the generic rate, so it sits above it in the list.
      special_rate = create(:commission_rate, store: store, value: 10, commission_tax_rate: 0.19)
      create(:commission_product_rule, commission_rate: special_rate, products: [special_product])
      rate.update!(commission_tax_rate: 0.05)

      lines = commission.index_by(&:line_item_id)

      expect(lines[special_line.id].tax_amount).to eq(1.9)
      expect(lines[generic.id].tax_amount).to eq(0.5)
    end

    # The figure alone cannot justify itself on an invoice — the seller has to
    # be able to see why their fee was taxed the way it was.
    it 'records the treatment and jurisdiction on the line' do
      line_for(seller)
      seller.update!(billing_address: build(:business_address, country_iso: 'DE'))
      allow_any_instance_of(Spree::TaxProvider::Internal).to receive(:service_tax_rate).and_return(0.19)

      line = commission.first

      expect(line.tax_rate).to eq(0.19)
      expect(line.taxability_reason).to eq('standard_rated')
      expect(line.country_code).to eq('DE')
    end

    # One rate governing a whole basket is one question about where the seller
    # sits, so the tax engine is consulted once rather than per item.
    it 'asks the tax engine once for a basket governed by one rate' do
      3.times { line_for(seller) }
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
      line = line_for(seller)
      line.variant.product.update!(seller: other_seller)

      expect(commission.first.seller).to eq(seller)
    end
  end
end
