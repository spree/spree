require 'spec_helper'

RSpec.describe Spree::Catalogs::SetProductTerms do
  let(:store) { @default_store }
  let(:catalog) { create(:catalog, store: store) }
  let(:product) { create(:product, store: store) }

  def apply(terms)
    described_class.call(catalog: catalog, terms: terms)
  end

  it 'writes a product pair to every one of its variants' do
    create(:variant, product: product)

    apply(product => { minimum_order_quantity: 48, order_multiple: 24 })

    rules = catalog.quantity_rules.reload
    expect(rules.count).to eq(product.variants_including_master.count)
    expect(rules.map(&:minimum_order_quantity).uniq).to eq([48])
  end

  # A term with nothing to apply to is not a state worth reaching.
  it 'adds a product that is not yet in the assortment' do
    expect { apply(product => { minimum_order_quantity: 48 }) }.
      to change { catalog.products.reload.count }.by(1)
  end

  it 'leaves a product already curated where it is' do
    catalog.add_products([product.id])

    expect { apply(product => { minimum_order_quantity: 48 }) }.
      not_to change { catalog.products.reload.count }
  end

  # An empty pair on the row is the merchant clearing the exception.
  it 'clears a product\'s terms when both fields are blank' do
    apply(product => { minimum_order_quantity: 48, order_multiple: 24 })

    apply(product => { minimum_order_quantity: '', order_multiple: nil })

    expect(catalog.quantity_rules.reload).to be_empty
  end

  it 'keeps one field when only the other is stated' do
    apply(product => { minimum_order_quantity: 48, order_multiple: nil })

    rule = catalog.quantity_rules.reload.first
    expect(rule.minimum_order_quantity).to eq(48)
    expect(rule.order_multiple).to be_nil
  end

  it 'updates terms already stated rather than duplicating them' do
    apply(product => { minimum_order_quantity: 48, order_multiple: 24 })

    expect { apply(product => { minimum_order_quantity: 96, order_multiple: 48 }) }.
      not_to change { catalog.quantity_rules.reload.count }

    expect(catalog.quantity_rules.reload.map(&:minimum_order_quantity).uniq).to eq([96])
  end

  it 'refuses a product from another store' do
    foreign = create(:product, store: create(:store))

    result = apply(foreign => { minimum_order_quantity: 48 })

    expect(result).to be_failure
    expect(catalog.quantity_rules.reload).to be_empty
  end

  it 'does nothing for an empty payload' do
    expect(apply({})).to be_success
  end
end
