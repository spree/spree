require 'spec_helper'

describe Spree::Property, :type => :model do

  let(:subject) { create(:property) }

  describe '#validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:presentation) }
    it { is_expected.to validate_uniqueness_of(:name).allow_nil }
  end
end
