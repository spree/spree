require 'spec_helper'
require 'rake'

describe 'spree:upgrade:populate_publications' do
  subject { Rake::Task[task_name] }

  let(:task_name) { 'spree:upgrade:populate_publications' }

  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'publications.rake')
  end

  before { subject.reenable }

  # Simulate the pre-5.5 catalog state: a row in +spree_products_stores+ for
  # the product/store pair, +Product#store_id+ nil, and no +ProductPublication+
  # for the store's default channel. The product factory auto-attaches both,
  # so we strip them and rebuild the legacy join row directly.
  def downgrade!(product, store)
    product.product_publications.destroy_all
    product.update_columns(store_id: nil)
    Spree::StoreProduct.create!(product: product, store: store)
  end

  let!(:default_store) { Spree::Store.default || create(:store, default: true) }

  context 'single store' do
    let!(:channel) { default_store.default_channel || create(:channel, store: default_store) }
    let!(:product) { create(:product, store: default_store) }

    before { downgrade!(product, default_store) }

    it 'creates a publication on the default channel' do
      expect { subject.invoke }.to change {
        Spree::ProductPublication.where(product_id: product.id, channel_id: channel.id).exists?
      }.from(false).to(true)
    end

    it 'sets store_id on the product' do
      expect { subject.invoke }.to change { product.reload.store_id }.from(nil).to(default_store.id)
    end

    it 'is idempotent — a re-run creates no extra publications' do
      subject.invoke
      subject.reenable
      expect { subject.invoke }.not_to change { Spree::ProductPublication.count }
    end
  end

  context 'multi-store catalog (single-store backfill mode)' do
    let!(:other_store) { create(:store, default: false) }
    let!(:default_channel) { default_store.default_channel || create(:channel, store: default_store) }
    let!(:other_channel) { other_store.default_channel || create(:channel, store: other_store) }
    let!(:product) { create(:product, store: default_store) }

    before do
      downgrade!(product, default_store)
      # Earliest legacy row wins for store_id. Backdate +default_store+'s
      # row so it's older than +other_store+'s and assert it's chosen.
      Spree::StoreProduct.where(product_id: product.id).update_all(created_at: 2.days.ago)
      Spree::StoreProduct.create!(product: product, store: other_store, created_at: 1.day.ago)
    end

    it 'publishes the product on every store it was attached to' do
      subject.invoke
      expect(Spree::ProductPublication.where(product_id: product.id).pluck(:channel_id))
        .to match_array([default_channel.id, other_channel.id])
    end

    it 'sets product.store_id from the earliest legacy row' do
      expect { subject.invoke }.to change { product.reload.store_id }.from(nil).to(default_store.id)
    end
  end

  context 'store without a default channel' do
    let!(:other_store) { create(:store, default: false) }
    let!(:product) { create(:product, store: default_store) }

    before do
      downgrade!(product, default_store)
      # Strip channels off +other_store+ to simulate the warning path.
      other_store.channels.delete_all
      Spree::StoreProduct.create!(product: product, store: other_store)
    end

    it 'skips that store with a warning and still processes the rest' do
      expect { subject.invoke }
        .to output(/has no default channel/).to_stdout
        .and change { product.reload.store_id }.from(nil).to(default_store.id)
    end
  end

  context 'legacy table not present' do
    before do
      allow(ActiveRecord::Base.connection).to receive(:table_exists?).and_call_original
      allow(ActiveRecord::Base.connection)
        .to receive(:table_exists?).with('spree_products_stores').and_return(false)
    end

    it 'no-ops with a message' do
      expect { subject.invoke }.to output(/nothing to migrate/).to_stdout
    end
  end
end
