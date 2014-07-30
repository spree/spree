require 'spec_helper'

describe Spree::ReturnItem::ReturnEligibilityValidator do
  let(:return_item) { create(:return_item) }
  let(:validator) { Spree::ReturnItem::ReturnEligibilityValidator.new(return_item) }

  describe "#eligible_for_return?" do
    subject { validator.eligible_for_return? }

    context "it is within the return timeframe" do
      it "returns true" do
        created_at = return_item.inventory_unit.created_at - (Spree::Config[:return_eligibility_number_of_days].days / 2)
        return_item.inventory_unit.stub(:created_at).and_return(created_at)
        expect(subject).to be true
      end
    end

    context "it is past the return timeframe" do
      before do
        created_at = return_item.inventory_unit.created_at - Spree::Config[:return_eligibility_number_of_days].days - 1.day
        return_item.inventory_unit.stub(:created_at).and_return(created_at)
      end

      it "returns false" do
        expect(subject).to be false
      end

      it "sets an error" do
        subject
        expect(validator.errors[:number_of_days]).to eq Spree.t('return_item_time_period_ineligible')
      end
    end
  end
end
