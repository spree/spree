require 'spec_helper'

RSpec.describe Spree::SampleData::Loader, type: :service do
  it 'warns that sample data moved to the Admin API and loads nothing' do
    expect(Spree::Deprecation).to receive(:warn).with(/spree sample-data/)

    expect { expect(described_class.call(store: @default_store)).to be_success }.
      not_to(change { Spree::Product.count })
  end
end
