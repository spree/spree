require 'spec_helper'

describe Spree::OptionValue, type: :model do
  describe 'Validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:option_type_id).case_insensitive.allow_blank }
  end

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
