require 'spec_helper'

describe Spree::PropertyPrototype do
  describe 'Validations' do
    it { is_expected.to validate_presence_of(:prototype) }
    it { is_expected.to validate_presence_of(:property) }
    it { is_expected.to validate_uniqueness_of(:prototype_id).scoped_to(:property_id).allow_nil }
  end
end
