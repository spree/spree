require 'spec_helper'

describe Spree::PromotionRuleUser do
  describe 'Validations' do
    it { is_expected.to validate_presence_of(:promotion_rule) }
    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_uniqueness_of(:user_id).scoped_to(:promotion_rule_id).allow_nil }
  end
end
