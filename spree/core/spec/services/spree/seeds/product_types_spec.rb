require 'spec_helper'

RSpec.describe Spree::Seeds::ProductTypes do
  subject { described_class.call }

  it 'creates the default and digital product types for every store' do
    subject

    types = Spree::ProductType.where(store: @default_store)
    expect(types.find_by(name: 'Default').fulfillment_types).to eq(['shipping'])
    expect(types.find_by(name: 'Digital').fulfillment_types).to eq(['digital'])
  end

  it 'is idempotent' do
    described_class.call

    expect { subject }.not_to change(Spree::ProductType, :count)
  end
end
