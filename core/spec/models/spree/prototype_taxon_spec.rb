require 'spec_helper'

describe Spree::PrototypeTaxon do
  describe 'Validations' do
    it { is_expected.to validate_presence_of(:prototype) }
    it { is_expected.to validate_presence_of(:taxon) }
    it { is_expected.to validate_uniqueness_of(:prototype_id).scoped_to(:taxon_id).allow_nil }
  end
end
