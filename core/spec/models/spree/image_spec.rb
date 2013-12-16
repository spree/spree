require 'spec_helper'

describe Spree::Image do
  let(:image) { build :image }
  subject { image }

  it 'should have valid factory' do
    should be_valid
  end

  describe '#attachment' do
    subject { image.attachment }

    it { should be_a Paperclip::Attachment }
  end
end
