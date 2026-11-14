require 'spec_helper'

RSpec.describe Spree::SampleData::LoadJob, type: :job do
  # A job queued by an earlier release may still be waiting when the upgrade lands.
  it 'runs without loading anything' do
    expect(Spree::Deprecation).to receive(:warn).with(/spree sample-data/)

    expect { described_class.perform_now(@default_store.id) }.not_to(change { Spree::Product.count })
  end
end
