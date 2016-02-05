require 'spec_helper'

describe Spree::OptionValue, :type => :model do
  context "touching" do
    it "should touch a variant" do
      variant = create(:variant)
      option_value = variant.option_values.first
      variant.update_column(:updated_at, 1.day.ago)
      option_value.touch
      expect(variant.reload.updated_at).to be_within(3.seconds).of(Time.current)
    end
  end
end
