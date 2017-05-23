require 'spec_helper'

describe Spree::Image, type: :model do

  describe 'callbacks' do
    it { is_expected.to callback(:find_dimensions).before(:save).if(:saved_change_to_attachment_updated_at?) }
  end
end
