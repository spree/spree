require 'spec_helper'

describe Spree::Tracker, type: :model do
  describe 'current' do
    before(:each) { @tracker = create(:tracker) }

    it 'returns the first active tracker' do
      expect(Spree::Tracker.current).to eq(@tracker)
    end

    it 'does not return an inactive tracker' do
      @tracker.update_attribute(:active, false)
      expect(Spree::Tracker.current).to be_nil
    end
  end
end
