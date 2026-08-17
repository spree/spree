require 'spec_helper'

RSpec.describe Spree::CommissionRules::ProductRule do
  let(:store) { @default_store }
  let(:rate) { create(:commission_rate, store: store) }
  let(:rule) { described_class.create!(commission_rate: rate) }

  # The sibling rules name their records through an id preference, which
  # raises on a foreign id. This one holds records, so it refuses on save
  # instead — a rate must not be narrowed to another marketplace's catalog.
  it 'refuses a product from another store' do
    rule.products = [create(:product, store: create(:store))]

    expect(rule).not_to be_valid
    expect(rule.errors[:products].first).to match(/belong to this store/)
  end

  it 'accepts a product from its own store' do
    rule.products = [create(:product, store: store)]

    expect(rule).to be_valid
  end

  it 'refuses a mixed list' do
    rule.products = [create(:product, store: store), create(:product, store: create(:store))]

    expect(rule).not_to be_valid
  end

  it 'matches a sale of a chosen product' do
    product = create(:product, store: store)
    rule.products = [product]
    rule.save!

    context = Spree::Commissions::Context.new(
      vendor: create(:vendor, :approved, store: store),
      order: create(:order, store: store),
      line_item: create(:line_item, variant: product.default_variant)
    )

    expect(rule.applicable?(context)).to be true
  end
end
