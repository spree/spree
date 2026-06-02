require 'spec_helper'
require 'rake'

describe 'spree:channels:backfill_product_publication_dates' do
  subject { Rake::Task[task_name] }

  let(:task_name) { 'spree:channels:backfill_product_publication_dates' }

  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'channels.rake')
  end

  before { subject.reenable }

  let!(:default_store) { Spree::Store.default || create(:store, default: true) }
  let!(:store) { create(:store, code: 'date_backfill', default: false) }

  # +update_columns+ skips the deprecated-setter cascade so the publication
  # starts with NULL dates (pre-upgrade state). Strip subseconds so the
  # round-trip through datetime(6) doesn't lose nanosecond residue on CI.
  let!(:product) do
    create(:product).tap do |p|
      p.update_columns(
        available_on:   2.years.ago.change(usec: 0),
        discontinue_on: 1.year.from_now.change(usec: 0)
      )
    end
  end
  # The product factory auto-publishes on the store's default channel, so
  # reuse that publication rather than creating another (which would collide
  # on the (product, channel) uniqueness index).
  let!(:publication) do
    product.product_publications.first.tap do |l|
      l.update_columns(published_at: nil, unpublished_at: nil)
    end
  end

  # +product.available_on+ / +product.discontinue_on+ go through the
  # +Product::Channels+ reader override which prefers the current-channel
  # publication's date over the legacy column. Read the raw attribute via
  # +[:column]+ to assert against the legacy value the rake task copies from.
  it 'copies available_on into published_at when published_at is NULL' do
    expect { subject.invoke }.to change { publication.reload.published_at }.from(nil).to(product[:available_on])
  end

  it 'copies discontinue_on into unpublished_at when unpublished_at is NULL' do
    subject.invoke
    expect(publication.reload.unpublished_at).to eq(product[:discontinue_on])
  end

  it 'preserves publication dates that are already populated' do
    custom_date = 6.months.from_now.change(usec: 0)
    publication.update_columns(published_at: custom_date)
    subject.invoke
    expect(publication.reload.published_at).to eq(custom_date)
  end
end
