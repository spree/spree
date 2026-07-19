require 'spec_helper'

RSpec.describe Spree::Seeds::ApiKeys do
  subject { described_class.call }

  before do
    Spree::Seeds::Stores.call
    Spree::Seeds::Channels.call
  end

  it 'creates an unbound default key and a wholesale-bound key' do
    subject

    store = Spree::Store.default
    wholesale = store.channels.find_by(code: 'wholesale')

    expect(store.api_keys.active.publishable.where(channel_id: nil)).to exist
    expect(store.api_keys.active.publishable.where(channel: wholesale)).to exist
  end

  it 'is idempotent' do
    described_class.call

    expect { subject }.not_to change { Spree::ApiKey.count }
  end
end
