require 'spec_helper'

RSpec.describe Spree::ApiKeys::MarkAsUsed, type: :job do
  let(:store) { create(:store) }
  let(:api_key) { create(:api_key, store: store) }

  describe '#perform' do
    let(:used_at) { Time.current }

    it 'updates last_used_at timestamp' do
      expect {
        described_class.new.perform(api_key.id, used_at)
      }.to change { api_key.reload.last_used_at }
    end

    it 'sets last_used_at to the provided timestamp' do
      used_at = Time.zone.parse('2025-06-15 12:00:00')
      described_class.new.perform(api_key.id, used_at)
      expect(api_key.reload.last_used_at).to eq(used_at)
    end

    it 'does not overwrite a newer last_used_at' do
      newer_time = 1.hour.from_now
      api_key.update_column(:last_used_at, newer_time)

      expect {
        described_class.new.perform(api_key.id, 2.hours.ago)
      }.not_to change { api_key.reload.last_used_at }
    end

    it 'does nothing for non-existent api key' do
      expect {
        described_class.new.perform(999999, used_at)
      }.not_to raise_error
    end

    it 'uses the api_keys queue' do
      expect(described_class.new.queue_name).to eq(Spree.queues.api_keys.to_s)
    end
  end
end
