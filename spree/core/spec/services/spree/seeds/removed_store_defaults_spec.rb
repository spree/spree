require 'spec_helper'

RSpec.describe Spree::Seeds::RemovedStoreDefaults do
  let(:store) { @default_store }

  it 'warns and creates nothing for a removed seed service' do
    expect(Spree::Deprecation).to receive(:warn).with(/Spree::Seeds::TaxCategories is deprecated.*spree config provision/)

    expect { Spree::Seeds::TaxCategories.call(store: store) }.not_to change(Spree::TaxCategory, :count)
  end

  it 'points provisioning callers at relocating the store' do
    expect(Spree::Deprecation).to receive(:warn).with(/Spree::Stores::ProvisionDefaults is deprecated.*Spree::Store#relocate/)

    result = Spree::Stores::ProvisionDefaults.call(store: store, country: store.default_country)

    expect(result).to be_success
  end
end
