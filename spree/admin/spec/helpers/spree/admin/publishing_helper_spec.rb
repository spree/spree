require 'spec_helper'

RSpec.describe Spree::Admin::PublishingHelper, type: :helper do
  let(:store) { @default_store }
  let(:channel) { store.default_channel }
  let(:product) { create(:product, store: store, status: 'active') }
  let(:publication) { product.product_publications.first }

  describe '#publication_schedule_status' do
    context 'when product status is not active' do
      it 'returns :not_available for draft' do
        expect(helper.publication_schedule_status('draft', publication)).to eq(:not_available)
      end

      it 'returns :not_available for archived' do
        expect(helper.publication_schedule_status('archived', publication)).to eq(:not_available)
      end
    end

    context 'when product is active' do
      it 'returns :live when no window is set' do
        publication.update!(published_at: nil, unpublished_at: nil)
        expect(helper.publication_schedule_status('active', publication)).to eq(:live)
      end

      it 'returns :scheduled when published_at is in the future' do
        publication.update!(published_at: 1.day.from_now)
        expect(helper.publication_schedule_status('active', publication)).to eq(:scheduled)
      end

      it 'returns :hidden when unpublished_at is in the past' do
        publication.update!(published_at: 2.days.ago, unpublished_at: 1.day.ago)
        expect(helper.publication_schedule_status('active', publication)).to eq(:hidden)
      end

      it 'returns :live when within the window' do
        publication.update!(published_at: 1.day.ago, unpublished_at: 1.day.from_now)
        expect(helper.publication_schedule_status('active', publication)).to eq(:live)
      end
    end
  end

  describe '#publication_status_badge' do
    it 'renders the label for the current status' do
      publication.update!(published_at: nil, unpublished_at: nil)
      expect(helper.publication_status_badge('active', publication)).to include(I18n.t('spree.admin.publishing.status_live'))
    end

    it 'falls back to :not_available when product is draft' do
      expect(helper.publication_status_badge('draft', publication)).to include(I18n.t('spree.admin.publishing.status_not_available'))
    end
  end

  describe '#publication_caption' do
    it 'returns the draft caption when product is not active' do
      caption = helper.publication_caption('draft', publication, store)
      expect(caption).to match(/Draft/)
    end

    it 'returns the live caption when active and window is open' do
      publication.update!(published_at: nil, unpublished_at: nil)
      expect(helper.publication_caption('active', publication, store)).to eq(I18n.t('spree.admin.publishing.caption_live'))
    end

    it 'returns the scheduled caption with a date' do
      future = 2.days.from_now
      publication.update!(published_at: future, unpublished_at: nil)
      caption = helper.publication_caption('active', publication, store)
      expect(caption).to include(I18n.l(future.in_time_zone(store.preferred_timezone), format: :short))
    end

    it 'returns the window caption when both endpoints are set in the future' do
      future_start = 1.day.from_now
      future_end = 3.days.from_now
      publication.update!(published_at: future_start, unpublished_at: future_end)
      caption = helper.publication_caption('active', publication, store)
      expect(caption).to include(I18n.l(future_start.in_time_zone(store.preferred_timezone), format: :short))
      expect(caption).to include(I18n.l(future_end.in_time_zone(store.preferred_timezone), format: :short))
    end

    it 'returns the hidden_after caption when live but with an end date' do
      future = 3.days.from_now
      publication.update!(published_at: 1.day.ago, unpublished_at: future)
      caption = helper.publication_caption('active', publication, store)
      expect(caption).to include(I18n.l(future.in_time_zone(store.preferred_timezone), format: :short))
    end
  end
end
