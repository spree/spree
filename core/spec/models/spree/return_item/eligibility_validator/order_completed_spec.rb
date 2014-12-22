require 'spec_helper'

describe Spree::ReturnItem::EligibilityValidator::OrderCompleted do
  let(:inventory_unit) { create(:inventory_unit, order: order) }
  let(:return_item)    { create(:return_item, inventory_unit: inventory_unit) }
  let(:validator)      { Spree::ReturnItem::EligibilityValidator::OrderCompleted.new(return_item) }

  describe "#eligible_for_return?" do
    subject { validator.eligible_for_return? }

    context "the order was completed" do
      let(:order) { create(:completed_order_with_totals) }

      it "returns true" do
        expect(subject).to be true
      end
    end

    context "the order is not completed" do
      let(:order) { create(:order) }

      it "returns false" do
        expect(subject).to be false
      end

      it "sets an error" do
        subject
        expect(validator.errors[:order_not_completed]).to eq Spree.t('return_item_order_not_completed')
      end
    end
  end
end
