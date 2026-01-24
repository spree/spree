require 'spec_helper'

RSpec.describe Spree::ApiKeyTouchJob, type: :job do
  let(:store) { create(:store) }
  let(:api_key) { create(:api_key, store: store) }

  describe '#perform' do
    it 'updates last_used_at timestamp' do
      expect {
        described_class.new.perform(api_key.id)
      }.to change { api_key.reload.last_used_at }
    end

    it 'does nothing for non-existent api key' do
      expect {
        described_class.new.perform(999999)
      }.not_to raise_error
    end

    it 'uses the api_keys queue' do
      expect(described_class.new.queue_name).to eq(Spree.queues.api_keys.to_s)
    end
  end

  describe 'enqueueing' do
    it 'enqueues the job' do
      expect {
        described_class.perform_later(api_key.id)
      }.to have_enqueued_job(described_class).with(api_key.id)
    end
  end
end
