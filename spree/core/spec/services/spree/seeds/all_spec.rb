require 'spec_helper'

RSpec.describe Spree::Seeds::All do
  subject { described_class.call }

  it 'runs without raising errors' do
    expect { subject }.not_to raise_error
  end

  describe 'upgrade records' do
    # A database seeded for the first time was created by today's schema, so
    # no past release has data to convert.
    it 'marks every release complete on a brand new database' do
      allow(Spree::Store).to receive(:none?).and_return(true)

      subject

      expect(Spree::UpgradeRecord.pluck(:source).uniq).to eq(['install'])
      expect(Spree::UpgradeRecord.pluck(:version)).to match_array(Spree::Upgrade.manifests.map { |manifest| manifest['to'] })
    end

    # Seeding is a common deploy step, and an upgraded store seeded before its
    # upgrade steps ran still has every one of them to do.
    it 'leaves an existing database to the upgrade walk' do
      subject

      expect(Spree::UpgradeRecord).not_to exist
    end

    it 'never rewrites a release the upgrade walk recorded' do
      allow(Spree::Store).to receive(:none?).and_return(true)
      walked = Spree::UpgradeRecord.stamp!(Spree::Upgrade.manifests.first['to'], source: 'walk')

      subject

      expect(walked.reload.source).to eq('walk')
    end
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

    # Everything a store trades with is the seeds engine's store defaults,
    # deployed once the store knows where it sells from.
    it 'leaves the store defaults to the seeds engine' do
      subject

      store = Spree::Store.find_by(default: true)
      expect(store).not_to be_provisioned
      expect(store.tax_categories).to be_empty
      expect(store.delivery_zones).to be_empty
      expect(Spree::ReturnReason.where(store: store)).to be_empty
    end
  end
end
