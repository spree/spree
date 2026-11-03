require 'spec_helper'

RSpec.describe Spree::Seeds::ApiKeys do
  subject { described_class.call }

  before { Spree::Seeds::Stores.call }

  it 'creates an unbound default key' do
    subject

    expect(Spree::Store.default.api_keys.active.publishable.where(channel_id: nil)).to exist
  end

  it 'is idempotent' do
    described_class.call

    expect { subject }.not_to change { Spree::ApiKey.count }
  end

  it 'seeds every store, not only the default' do
    second_store = create(:store)

    subject

    expect(second_store.api_keys.active.publishable.where(channel_id: nil)).to exist
  end
end
