require 'spec_helper'

RSpec.describe Spree::SampleData::Loader, type: :service, without_global_store: true do
  before(:all) do
    DatabaseCleaner.clean_with(:truncation)
    described_class.call
  end

  after(:all) do
    DatabaseCleaner.clean_with(:truncation)
  end

  it 'creates products' do
    expect(Spree::Product.count).to be > 50
  end

  it 'creates variants' do
    expect(Spree::Variant.count).to be > 100
  end

  it 'creates customers' do
    expect(Spree.user_class.where.not(email: 'spree@example.com').count).to be > 5
  end

  it 'creates completed orders' do
    expect(Spree::Order.complete.count).to be >= 2
  end
end
