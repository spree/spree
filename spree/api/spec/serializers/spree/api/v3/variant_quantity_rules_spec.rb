require 'spec_helper'

RSpec.describe Spree::Api::V3::VariantSerializer, 'quantity rules' do
  let(:store) { @default_store }
  let(:product) { create(:product, store: store) }
  let(:variant) { product.default_variant }

  def render(user: nil)
    described_class.new(
      variant, params: { store: store, currency: store.default_currency, user: user }
    ).to_h
  end

  before do
    Spree::Current.store = store
    Spree::Current.reset_catalog_memos
  end

  it 'reads 1 and 1 when nothing declares a rule' do
    json = render

    expect(json['minimum_order_quantity']).to eq(1)
    expect(json['order_multiple']).to eq(1)
    expect(json['purchase_unit']).to eq('unit')
  end

  it "falls back to the variant's own rules for a buyer with no agreement" do
    variant.update!(minimum_order_quantity: 6, order_multiple: 3)

    json = render(user: create(:user))

    expect(json['minimum_order_quantity']).to eq(6)
    expect(json['order_multiple']).to eq(3)
  end

  # The stepper a storefront draws has to match the quantity the cart will
  # accept. Resolving without the buyer's company would answer from a
  # different agreement than the one pricing the same page.
  it "renders the terms of the buyer's company agreement" do
    customer = create(:user)
    company = create(:company, store: store)
    catalog = create(:catalog, store: store, minimum_order_quantity: 48, order_multiple: 24)
    create(:company_membership, company: company, customer: customer)
    create(:catalog_assignment, catalog: catalog, assignable: company)
    Spree::Current.reset_catalog_memos

    json = render(user: customer)

    expect(json['minimum_order_quantity']).to eq(48)
    expect(json['order_multiple']).to eq(24)
  end

  it 'exposes the carton vocabulary when the variant is quoted in cartons' do
    variant.update!(purchase_unit: 'carton', units_per_carton: 24)

    json = render

    expect(json['purchase_unit']).to eq('carton')
    expect(json['units_per_carton']).to eq(24)
  end
end
