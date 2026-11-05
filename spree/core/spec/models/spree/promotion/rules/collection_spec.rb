require 'spec_helper'

RSpec.describe Spree::Promotion::Rules::Collection, type: :model do
  let(:store) { @default_store }
  let(:promotion) { create(:promotion, store: store) }
  let(:rule) { described_class.create!(promotion: promotion, collection_ids: [summer.prefixed_id]) }
  let(:summer) { create(:collection, store: store) }
  let(:winter) { create(:collection, store: store) }
  let(:in_summer) { create(:product, store: store) }
  let(:in_winter) { create(:product, store: store) }
  let(:order) { create(:order_with_line_items, store: store, line_items_count: 1) }

  before do
    Spree::Collections::AddProducts.call(collections: [summer], products: [in_summer])
    Spree::Collections::AddProducts.call(collections: [winter], products: [in_winter])
  end

  def order_with(*products)
    allow(order).to receive(:product_ids).and_return(products.map(&:id))
    order
  end

  it 'is eligible when the order has a product from a collection' do
    expect(rule).to be_eligible(order_with(in_summer))
    expect(rule).not_to be_eligible(order_with(in_winter))
  end

  it 'needs a product from every collection with the all policy' do
    rule.update!(collection_ids: [summer.id, winter.id], preferred_match_policy: 'all')

    expect(described_class.find(rule.id)).not_to be_eligible(order_with(in_summer))
    expect(described_class.find(rule.id)).to be_eligible(order_with(in_summer, in_winter))
  end

  it 'discounts only collection members' do
    expect(rule.actionable?(build(:line_item, product: in_summer))).to be(true)
    expect(rule.actionable?(build(:line_item, product: in_winter))).to be(false)
  end

  it 'refuses a collection of another store' do
    foreign = create(:collection, store: create(:store))

    expect { described_class.create!(promotion: promotion, collection_ids: [foreign.prefixed_id]) }.
      to raise_error(ActiveRecord::RecordNotFound)
  end
end
