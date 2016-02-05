require 'spec_helper'

describe Spree::PromotionRuleTaxon do
  describe 'Validations' do
    it { is_expected.to validate_presence_of(:promotion_rule) }
    it { is_expected.to validate_presence_of(:taxon) }
    it { is_expected.to validate_uniqueness_of(:promotion_rule_id).scoped_to(:taxon_id).allow_nil }
  end
end
