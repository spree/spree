require 'spec_helper'

describe Spree::PromotionCode do

  describe "normalize_value" do
    let(:code) { create(:promotion_code, value: '  BaNaNA ') }

    it "will strip and downcase value" do
      expect(code.value).to eq 'banana'
    end
  end

  describe "expired?" do
    let(:code) { create(:promotion_code) }

    it "is true before starts_at" do
      code.update_attribute(:starts_at, Date.tomorrow)
      expect(code.expired?).to be_true
    end

    it "is true after expires_at" do
      code.update_attribute(:expires_at, Date.yesterday)
      expect(code.expired?).to be_true
    end
  end

  describe "usage_limit_exceeded?" do
    let(:code) { create(:promotion_code) }

    it "false if usage_limit is nil or 0" do
      code.update_attribute(:usage_limit, 0)
      expect(code.usage_limit_exceeded?).to be_false
    end

    pending "if used up, is invalid"
    pending "keeps track of number of times used"
  end

end
