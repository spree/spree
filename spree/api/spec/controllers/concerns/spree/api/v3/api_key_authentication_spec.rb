require 'spec_helper'

RSpec.describe 'API Key Authentication Touch Throttling', type: :controller do
  describe Spree::Api::V3::Store::StoresController do
    controller(Spree::Api::V3::Store::StoresController) {}

    render_views

    include_context 'API v3 Store'

    describe 'touch throttling for publishable keys' do
      before do
        request.headers['X-Spree-Api-Key'] = api_key.token
      end

      context 'when last_used_at is nil' do
        before { api_key.update_column(:last_used_at, nil) }

        it 'enqueues the mark as used job' do
          expect {
            get :show, params: { id: store.prefixed_id }
          }.to have_enqueued_job(Spree::ApiKeys::MarkAsUsed).with(api_key.id, instance_of(ActiveSupport::TimeWithZone))
        end
      end

      context 'when last_used_at is more than 1 hour ago' do
        before { api_key.update_column(:last_used_at, 2.hours.ago) }

        it 'enqueues the mark as used job' do
          expect {
            get :show, params: { id: store.prefixed_id }
          }.to have_enqueued_job(Spree::ApiKeys::MarkAsUsed).with(api_key.id, instance_of(ActiveSupport::TimeWithZone))
        end
      end

      context 'when last_used_at is less than 1 hour ago' do
        before { api_key.update_column(:last_used_at, 30.minutes.ago) }

        it 'does not enqueue the mark as used job' do
          expect {
            get :show, params: { id: store.prefixed_id }
          }.not_to have_enqueued_job(Spree::ApiKeys::MarkAsUsed)
        end
      end
    end
  end
end
