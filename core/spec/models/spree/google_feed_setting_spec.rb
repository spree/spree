require 'spec_helper'

describe Spree::GoogleFeedSetting, type: :model do
  let(:store) { create(:store) }
  let(:google_feed_setting) { create(:google_feed_setting, store: store) }

  describe '#enabled_keys' do
    it 'returns enabled key' do
      expect(google_feed_setting.enabled_keys).to include(:brand)
    end

    it 'does not return not enabled key' do
      expect(google_feed_setting.enabled_keys).not_to include(:size)
    end
  end
end
