require 'spec_helper'

describe Spree::Property, type: :model do
  let!(:property) { create(:property) }
  describe 'Validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:presentation) }
    it { is_expected.to validate_uniqueness_of(:name).case_insensitive.allow_blank }
  end
end
