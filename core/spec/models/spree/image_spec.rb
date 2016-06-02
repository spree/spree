require 'spec_helper'

describe Spree::Image, type: :model do

  describe 'callbacks' do
    it { is_expected.to callback(:find_dimensions).before(:save).if(:attachment_updated_at_changed?) }
  end
end
