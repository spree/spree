# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::HasListPosition do
  it 'orders by position then id' do
    store = create(:store)
    first = create(:market, store: store, name: 'First')
    second = create(:market, store: store, name: 'Second')
    third = create(:market, store: store, name: 'Third')

    third.insert_at(1)
    first.insert_at(2)

    ordered = store.markets.ordered.where(id: [first.id, second.id, third.id])
    expect(ordered.pluck(:name)).to eq(%w[Third First Second])
  end

  it 'keeps ordering unambiguous when a join is present' do
    store = create(:store)
    first = create(:collection, store: store, name: 'First', permalink: 'first-sale')
    second = create(:collection, store: store, name: 'Second', permalink: 'second-sale')

    first.insert_at(2)

    ordered = store.collections.ordered.ransack(permalink_cont: 'sale').result
    expect(ordered.pluck(:name)).to eq(%w[Second First])
  end
end
