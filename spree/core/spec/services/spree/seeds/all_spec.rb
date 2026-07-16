require 'spec_helper'

# Seeds bootstrap a store from scratch, so run without the shared global store.
RSpec.describe Spree::Seeds::All, without_global_store: true do
  subject { described_class.call }

  before { Spree::Store.where(default: true).delete_all }

  it 'runs without raising errors' do
    expect { subject }.not_to raise_error
  end

  # Shipping calculators are seeded before the default store exists; their
  # currency preference default must not reach for the deprecated
  # Spree::Store.default fallback.
  it 'does not emit the unpersisted default store deprecation' do
    allow(Spree::Deprecation).to receive(:warn)
    subject
    expect(Spree::Deprecation).not_to have_received(:warn).with(a_string_matching(/unpersisted store/))
  end
end
