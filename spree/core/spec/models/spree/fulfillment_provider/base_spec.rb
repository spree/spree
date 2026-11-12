require 'spec_helper'

describe Spree::FulfillmentProvider::Base, type: :model do
  subject(:provider) { described_class.new }

  let(:fulfillment) { build(:fulfillment) }

  it 'allows fulfillment by default and does not auto-fulfill' do
    expect(provider.can_fulfill?(fulfillment)).to be(true)
    expect(provider.auto_fulfill?).to be(false)
    expect(provider.tracking_url(fulfillment)).to be_nil
    expect(provider.documents(fulfillment)).to eq([])
  end

  it 'requires create/cancel in subclasses' do
    expect { provider.create_fulfillment(fulfillment) }.to raise_error(NotImplementedError)
    expect { provider.cancel_fulfillment(fulfillment) }.to raise_error(NotImplementedError)
  end

  describe 'Fulfillment#provider' do
    it 'falls back to Manual without a delivery method' do
      expect(build(:fulfillment).provider).to be_a(Spree::FulfillmentProvider::Manual)
    end
  end
end
