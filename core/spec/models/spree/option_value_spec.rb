require 'spec_helper'

describe Spree::OptionValue do
  context "touching" do
    it "should touch a variant" do
      variant = create(:variant)
      option_value = variant.option_values.first
      variant.update_column(:updated_at, 1.day.ago)
      option_value.touch
      variant.reload.updated_at.should be_within(3.seconds).of(Time.now)
    end
  end
end