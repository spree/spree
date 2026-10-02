require 'spec_helper'

RSpec.describe Spree::Seeds::All do
  subject { described_class.call }

  it 'runs without raising errors' do
    expect { subject }.not_to raise_error
  end

  it 'gives every store its first publishable key' do
    other_store = create(:store)

    subject

    [@default_store, other_store].each do |store|
      expect(store.api_keys.active.publishable.where(channel_id: nil)).to exist
    end
  end

  # Store-scoped seeds iterate `Spree::Store.all`, so one ordered before
  # `Stores` silently creates nothing on a fresh install.
  context 'on a fresh install, with no store yet', :without_global_store do
    it 'creates the store with its admin role and first key' do
      subject

      store = Spree::Store.find_by(default: true)
      expect(Spree::Role.default_admin_role(store)).not_to be_mutable
      expect(store.api_keys.publishable).to exist
    end

    # Everything a store trades with is the configurator's store defaults,
    # deployed once the store knows where it sells from.
    it 'leaves the store defaults to the configurator' do
      subject

      store = Spree::Store.find_by(default: true)
      expect(store).not_to be_provisioned
      expect(store.tax_categories).to be_empty
      expect(store.delivery_zones).to be_empty
      expect(Spree::ReturnReason.where(store: store)).to be_empty
    end
  end
end
