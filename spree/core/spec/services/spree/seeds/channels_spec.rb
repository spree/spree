require 'spec_helper'

RSpec.describe Spree::Seeds::Channels do
  subject { described_class.call }

  before do
    Spree::Seeds::Stores.call
  end

  it 'creates a gated wholesale channel on the default store' do
    subject

    wholesale = Spree::Store.default.channels.find_by(code: 'wholesale')
    expect(wholesale).to be_present
    expect(wholesale.resolved_storefront_access).to eq('login_required')
    expect(wholesale.resolved_guest_checkout).to be false
    expect(wholesale.default).to be false
  end

  it 'is idempotent' do
    described_class.call

    expect { subject }.not_to change { Spree::Channel.count }
  end

  it 'seeds every store, not only the default' do
    second_store = create(:store)

    subject

    expect(second_store.channels.find_by(code: 'wholesale')).to be_present
  end
end
