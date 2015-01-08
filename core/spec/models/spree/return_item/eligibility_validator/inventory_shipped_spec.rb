require 'spec_helper'

describe Spree::ReturnItem::EligibilityValidator::InventoryShipped do
  let(:return_item) { create(:return_item) }
  let(:validator)   { Spree::ReturnItem::EligibilityValidator::InventoryShipped.new(return_item) }

  describe "#eligible_for_return?" do
    before { allow(return_item.inventory_unit).to receive(:shipped?).and_return(true) }

    subject { validator.eligible_for_return? }

    context "the associated inventory unit is shipped" do
      it "returns true" do
        expect(subject).to eq true
      end
    end

    context "the associated inventory unit is not shipped" do
      before { allow(return_item.inventory_unit).to receive(:shipped?).and_return(false) }

      it "returns false" do
        expect(subject).to eq false
      end

      it "sets an error" do
        subject
        expect(validator.errors[:inventory_unit_shipped]).to eq Spree.t('return_item_inventory_unit_ineligible')
      end
    end
  end

  describe "#requires_manual_intervention?" do
    subject { validator.requires_manual_intervention? }

    context "not eligible for return" do
      before do
        allow(return_item.inventory_unit).to receive(:shipped?).and_return(false)
        validator.eligible_for_return?
      end

      it 'returns true if errors were added' do
        expect(subject).to eq true
      end
    end

    context "eligible for return" do
      before do
        allow(return_item.inventory_unit).to receive(:shipped?).and_return(true)
        validator.eligible_for_return?
      end

      it 'returns false if no errors were added' do
        expect(subject).to eq false
      end
    end

  end
end
