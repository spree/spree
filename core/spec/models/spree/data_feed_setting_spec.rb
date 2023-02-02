require 'spec_helper'

describe Spree::DataFeedSetting, type: :model do
  let(:store) { create(:store) }
  let(:data_feed_setting) { create(:data_feed_setting, store: store) }

  # TODO
end
