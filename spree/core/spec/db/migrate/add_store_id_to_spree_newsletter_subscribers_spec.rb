require 'spec_helper'

# The backfill reads the default store without the model, so it has to choose
# the same store Spree::Store.default does when an upgraded or imported
# database holds more than one store flagged as default.
RSpec.describe 'AddStoreIdToSpreeNewsletterSubscribers migration', without_global_store: true do
  let(:migration) do
    require Spree::Core::Engine.root.join(
      'db', 'migrate', '20260515000001_add_store_id_to_spree_newsletter_subscribers.rb'
    )
    AddStoreIdToSpreeNewsletterSubscribers.new
  end

  # Build our own stores and flag them as default with update_columns, which
  # skips the model's single-default guard: that is the imported-data case.
  # A store left behind by another spec's setup is unflagged; the example's
  # transaction rolls that back.
  before { Spree::Store.where(default: true).update_all(default: false) }

  def default_store(created_at:)
    create(:store).tap { |store| store.update_columns(default: true, created_at: created_at) }
  end

  describe '#find_default_store_id' do
    it 'returns the only default store' do
      store = default_store(created_at: 1.day.ago)
      create(:store)

      expect(migration.send(:find_default_store_id)).to eq(store.id)
    end

    it 'picks the oldest default store when several are flagged default' do
      oldest = default_store(created_at: 2.days.ago)
      default_store(created_at: 1.day.ago)

      expect(migration.send(:find_default_store_id)).to eq(oldest.id)
      expect(migration.send(:find_default_store_id)).to eq(Spree::Store.default.id)
    end

    it 'picks the oldest default store even when it has the higher id' do
      default_store(created_at: 1.day.ago)
      oldest = default_store(created_at: 2.days.ago)

      expect(migration.send(:find_default_store_id)).to eq(oldest.id)
      expect(migration.send(:find_default_store_id)).to eq(Spree::Store.default.id)
    end

    it 'skips a deleted default store' do
      default_store(created_at: 2.days.ago).update_columns(deleted_at: Time.current)
      live = default_store(created_at: 1.day.ago)

      expect(migration.send(:find_default_store_id)).to eq(live.id)
    end
  end
end
