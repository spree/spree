require 'spec_helper'

RSpec.describe Spree::CatalogQuantityRule do
  let(:store) { @default_store }
  let(:catalog) { create(:catalog, store: store) }
  let(:variant) { create(:variant, product: create(:product, store: store)) }

  it 'refuses a row that states neither field' do
    rule = build(:catalog_quantity_rule, catalog: catalog, variant: variant,
                                         minimum_order_quantity: nil, order_multiple: nil)

    expect(rule).not_to be_valid
    expect(rule.errors[:base]).to be_present
  end

  it 'accepts a row stating only one field' do
    rule = build(:catalog_quantity_rule, catalog: catalog, variant: variant,
                                         minimum_order_quantity: 48, order_multiple: nil)

    expect(rule).to be_valid
  end

  it 'refuses a variant belonging to another store' do
    foreign = create(:variant, product: create(:product, store: create(:store)))
    rule = build(:catalog_quantity_rule, catalog: catalog, variant: foreign)

    expect(rule).not_to be_valid
    expect(rule.errors[:variant]).to be_present
  end

  it 'allows only one row per catalog and variant' do
    create(:catalog_quantity_rule, catalog: catalog, variant: variant)
    duplicate = build(:catalog_quantity_rule, catalog: catalog, variant: variant)

    expect(duplicate).not_to be_valid
  end

  it 'enforces the uniqueness in the database as well' do
    create(:catalog_quantity_rule, catalog: catalog, variant: variant)

    expect {
      described_class.new(catalog: catalog, variant: variant, minimum_order_quantity: 6).
        save(validate: false)
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'refuses a zero or negative quantity' do
    expect(build(:catalog_quantity_rule, catalog: catalog, variant: variant, minimum_order_quantity: 0)).not_to be_valid
    expect(build(:catalog_quantity_rule, catalog: catalog, variant: variant, order_multiple: -2)).not_to be_valid
  end
end
