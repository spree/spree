require 'spec_helper'

RSpec.describe Spree::Catalogs::Activate do
  let(:store) { @default_store }
  let(:catalog) { create(:catalog, :inactive, store: store) }

  it 'puts an assigned agreement into effect' do
    create(:catalog_assignment, catalog: catalog, assignable: create(:company, store: store))

    expect(described_class.call(catalog: catalog)).to be_success
    expect(catalog.reload).to be_active
  end

  # An agreement nobody is assigned to reaches no buyer, so activating it
  # would change nothing.
  it 'refuses a catalog nobody is assigned to' do
    result = described_class.call(catalog: catalog)

    expect(result).to be_failure
    expect(catalog.reload).not_to be_active
    expect(catalog.errors[:base].join).to include('assigned')
  end

  # The exception the rule needs: a channel's default catalog is reached
  # through the channel rather than through an assignment.
  it 'activates a channel default catalog with no assignments' do
    create(:channel, store: store, default_catalog: catalog)

    expect(described_class.call(catalog: catalog)).to be_success
    expect(catalog.reload).to be_active
  end

  # The hook is where sweeping caches and telling the companies it covers
  # will hang, so it has to run with the change already applied.
  context 'with an after_activate handler' do
    before { Spree.hooks.clear! }
    after { Spree.hooks.clear! }

    it 'runs it once the catalog is live' do
      create(:catalog_assignment, catalog: catalog, assignable: create(:company, store: store))
      seen = nil
      Spree.hooks.register('catalogs.activate.after_activate') { |flow| seen = flow.catalog.active? }

      described_class.call(catalog: catalog)

      expect(seen).to be(true)
    end
  end
end
