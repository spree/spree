require 'spec_helper'

RSpec.describe Spree::Seeds::AllowedOrigins do
  subject { described_class.call }

  let(:store) { @default_store }

  it 'creates a localhost allowed origin' do
    expect { subject }.to change(Spree::AllowedOrigin, :count).by(1)

    origin = store.allowed_origins.last
    expect(origin.origin).to eq('http://localhost')
  end

  context 'when the allowed origin already exists' do
    before do
      create(:allowed_origin, store: store, origin: 'http://localhost')
    end

    it 'does not create a duplicate' do
      expect { subject }.not_to change(Spree::AllowedOrigin, :count)
    end
  end

  context 'when no default store exists' do
    before do
      Spree::Store.destroy_all
    end

    it 'does not raise an error' do
      expect { subject }.not_to raise_error
    end
  end
end
