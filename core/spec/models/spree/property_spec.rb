require 'spec_helper'

describe Spree::Property, type: :model do
  describe 'Validations' do
    subject { Spree::Property.new(name: "brand", presentation: "brand") }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:presentation) }
    it { is_expected.to validate_uniqueness_of(:name).case_insensitive }
    it { is_expected.to validate_uniqueness_of(:presentation).case_insensitive }
  end
end
