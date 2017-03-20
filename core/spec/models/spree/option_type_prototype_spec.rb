require 'spec_helper'

describe Spree::OptionTypePrototype do
  describe 'Validations' do
    it { is_expected.to validate_presence_of(:prototype) }
    it { is_expected.to validate_presence_of(:option_type) }
    it { is_expected.to validate_uniqueness_of(:prototype_id).scoped_to(:option_type_id).allow_nil }
  end
end
