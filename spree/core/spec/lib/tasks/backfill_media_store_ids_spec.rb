require 'spec_helper'
require 'rake'

describe 'spree:upgrade:backfill_media_store_ids' do
  subject { Rake::Task[task_name] }

  let(:task_name) { 'spree:upgrade:backfill_media_store_ids' }

  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'backfill_media_store_ids.rake')
  end

  before { subject.reenable }

  let(:store) { Spree::Store.default }

  # Simulates a pre-6.0 row: the column exists but nothing has filled it in.
  def unown!(*media)
    Spree::Media.unscoped.where(id: media.map(&:id)).update_all(store_id: nil)
  end

  it 'takes a product-owned row from its product' do
    other_store = create(:store)
    media = create(:image, viewable: create(:product, store: other_store))
    unown!(media)

    subject.invoke

    expect(media.reload.store).to eq(other_store)
  end

  it 'takes a variant-owned row from the variant product' do
    other_store = create(:store)
    variant = create(:variant, product: create(:product, store: other_store))
    media = create(:asset, viewable: variant)
    unown!(media)

    subject.invoke

    expect(media.reload.store).to eq(other_store)
  end

  # An unowned row is invisible to every library query, so it has to land
  # somewhere rather than stay unreachable.
  it 'gives a row with no viewable to the default store' do
    media = create(:image, viewable: nil)
    unown!(media)

    subject.invoke

    expect(media.reload.store).to eq(store)
  end

  it 'gives a row whose viewable is gone to the default store' do
    media = create(:image, viewable: create(:product))
    unown!(media)
    Spree::Media.unscoped.where(id: media.id).update_all(viewable_id: 0)

    subject.invoke

    expect(media.reload.store).to eq(store)
  end

  it 'leaves a row that already has a store alone' do
    other_store = create(:store)
    media = create(:image, viewable: nil)
    Spree::Media.unscoped.where(id: media.id).update_all(store_id: other_store.id)

    subject.invoke

    expect(media.reload.store).to eq(other_store)
  end

  it 'can be run twice' do
    media = create(:image, viewable: create(:product))
    unown!(media)

    subject.invoke
    subject.reenable
    expect { subject.invoke }.not_to raise_error

    expect(media.reload.store).to be_present
  end
end
