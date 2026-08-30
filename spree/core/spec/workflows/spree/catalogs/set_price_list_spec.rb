require 'spec_helper'

# The inline price-list payload: a catalog and the list it prices through are
# written together (docs/plans/6.0-catalog-agreement-rework.md).
describe Spree::Catalogs::SetPriceList do
  let(:store) { @default_store }
  let(:catalog) { create(:catalog, store: store, name: 'Wholesale') }

  def call(attributes)
    described_class.call(catalog: catalog, attributes: attributes)
  end

  it 'creates the owned list, naming it after the catalog' do
    expect(call(price_adjustment_percentage: '-15')).to be_success

    list = catalog.reload.price_list
    expect(list.name).to eq('Wholesale')
    expect(list.price_adjustment_percentage).to eq(-15)
  end

  # The catalog's own `active` flag already gates the agreement; a second
  # dormant switch inside it would only configure pricing that does nothing.
  it 'gives the new list an active status rather than draft' do
    call(price_adjustment_percentage: '-15')

    expect(catalog.reload.price_list).to be_active
  end

  it 'honours an explicit name and status' do
    call(name: 'Negotiated', status: 'draft', price_adjustment_percentage: '-5')

    list = catalog.reload.price_list
    expect(list.name).to eq('Negotiated')
    expect(list).to be_draft
  end

  it 'updates the list already owned rather than making a second one' do
    call(price_adjustment_percentage: '-15')
    original_id = catalog.reload.price_list.id

    expect { call(price_adjustment_percentage: '-20') }.not_to change { store.price_lists.count }

    expect(catalog.reload.price_list.id).to eq(original_id)
    expect(catalog.price_list.price_adjustment_percentage).to eq(-20)
  end

  # Detaching releases the list to standalone matching, so it is only ever an
  # explicit act — and the list itself survives, since it holds prices someone
  # entered.
  it 'detaches on a blank payload, keeping the list' do
    call(price_adjustment_percentage: '-15')
    list = catalog.reload.price_list

    expect(described_class.call(catalog: catalog, attributes: nil)).to be_success

    expect(catalog.reload.price_list).to be_nil
    expect(list.reload.catalog_id).to be_nil
    expect(list).to be_persisted
  end

  it 'is a no-op when detaching a catalog that owns nothing' do
    expect(described_class.call(catalog: catalog, attributes: nil)).to be_success
    expect(catalog.reload.price_list).to be_nil
  end

  it 'fails without creating a list when the adjustment is invalid' do
    result = nil
    expect { result = call(price_adjustment_percentage: '-100') }.
      not_to change { store.price_lists.count }

    expect(result).not_to be_success
    expect(catalog.reload.price_list).to be_nil
  end
end
