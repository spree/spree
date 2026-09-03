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
end
