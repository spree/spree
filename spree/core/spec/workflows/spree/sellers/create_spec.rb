require 'spec_helper'

RSpec.describe Spree::Sellers::Create do
  let(:store) { @default_store }

  # `Store#default_stock_location` memoizes, and creates the row when there is
  # none. The suite shares one store instance, so an example that creates it
  # leaves the memo pointing at a row the next example's rollback has already
  # removed — and `reload` then raises RecordNotFound on PostgreSQL, where
  # examples run inside a transaction. Dropping the memo makes each example
  # ask the database again.
  before { store.remove_instance_variable(:@default_stock_location) if store.instance_variable_defined?(:@default_stock_location) }

  subject { described_class.call(store: store, attributes: attributes) }

  let(:attributes) { { name: 'Sparks' } }

  it 'creates the seller' do
    expect(subject).to be_success
    expect(subject.value.name).to eq('Sparks')
  end

  # A seller with nowhere to keep stock has nowhere for returns to go either,
  # so provisioning it is part of creating them.
  it 'provisions a stock location named after the seller' do
    seller = subject.value

    expect(seller.stock_locations.count).to eq(1)
    expect(seller.stock_locations.first).to have_attributes(name: 'Sparks', default: true, active: true)
  end

  it 'makes that location the seller returns route' do
    seller = subject.value

    expect(seller.returns_location).to eq(seller.stock_locations.first)
  end

  # The default flag is per owner, so a seller's default must not demote the
  # marketplace's own.
  it 'leaves the operator default alone' do
    operator_default = store.default_stock_location

    subject

    expect(operator_default.reload).to be_default
  end

  # Two sellers may each call their warehouse the same thing, which is what a
  # marketplace looks like.
  it 'allows two sellers to hold a location with the same name' do
    first = described_class.call(store: store, attributes: { name: 'Sparks' }).value
    second = described_class.call(store: store, attributes: { name: 'Embers' }).value

    second.stock_locations.first.update!(name: first.stock_locations.first.name)

    expect(second.stock_locations.first.reload.name).to eq('Sparks')
  end

  # The operator may hold one by that name too.
  it 'allows a seller location to share a name with the operator' do
    operator_name = store.default_stock_location.name
    seller = described_class.call(store: store, attributes: { name: 'Sparks' }).value

    expect(seller.stock_locations.first.update(name: operator_name)).to be(true)
  end

  # Within one seller, though, names still have to be distinct.
  it 'refuses a duplicate name within the same seller' do
    seller = subject.value
    duplicate = seller.stock_locations.new(store: store, name: seller.stock_locations.first.name)

    expect(duplicate).not_to be_valid
  end


  it 'fails without a name, and writes no location' do
    result = described_class.call(store: store, attributes: { name: '' })

    expect(result).not_to be_success
    expect(store.stock_locations.where.not(seller_id: nil)).to be_empty
  end
end
