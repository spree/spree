require 'spec_helper'

describe Spree::ReimbursementItem do

  describe "#exchange_requested?" do
    context "exchange variant exists" do
      before { subject.stub(:exchange_variant) { mock_model(Spree::Variant) } }
      it { expect(subject.exchange_requested?).to eq true }
    end
    context "exchange variant does not exist" do
      before { subject.stub(:exchange_variant) { nil } }
      it { expect(subject.exchange_requested?).to eq false }
    end
  end

  describe "#exchange_processed?" do
    context "exchange inventory unit exists" do
      before { subject.stub(:exchange_inventory_unit) { mock_model(Spree::InventoryUnit) } }
      it { expect(subject.exchange_processed?).to eq true }
    end
    context "exchange inventory unit does not exist" do
      before { subject.stub(:exchange_inventory_unit) { nil } }
      it { expect(subject.exchange_processed?).to eq false }
    end
  end

  describe "#exchange_required?" do
    context "exchange has been requested and not yet processed" do
      before do
        subject.stub(:exchange_requested?) { true }
        subject.stub(:exchange_processed?) { false }
      end

      it { expect(subject.exchange_required?).to be_true }
    end

    context "exchange has not been requested" do
      before { subject.stub(:exchange_requested?) { false } }
      it { expect(subject.exchange_required?).to be_false }
    end

    context "exchange has been requested and processed" do
      before do
        subject.stub(:exchange_requested?) { true }
        subject.stub(:exchange_processed?) { true }
      end
      it { expect(subject.exchange_required?).to be_false }
    end
  end

  describe "exchange pre_tax_amount" do
    let(:reimbursement_item) { build(:reimbursement_item) }

    context "the reimbursement item is intended to be exchanged" do
      before { reimbursement_item.exchange_variant = build(:variant) }
      it do
        reimbursement_item.pre_tax_amount = 5.0
        reimbursement_item.save!
        expect(reimbursement_item.reload.pre_tax_amount).to eq 0.0
      end
    end

    context "the reimbursement item is not intended to be exchanged" do
      it do
        reimbursement_item.pre_tax_amount = 5.0
        reimbursement_item.save!
        expect(reimbursement_item.reload.pre_tax_amount).to eq 5.0
      end
    end
  end

  describe "#build_exchange_inventory_unit" do
    let(:reimbursement_item) { build(:reimbursement_item) }
    subject { reimbursement_item.build_exchange_inventory_unit }

    context "the reimbursement item is intended to be exchanged" do
      before { reimbursement_item.stub(:exchange_variant).and_return(mock_model(Spree::Variant)) }

      context "an exchange inventory unit already exists" do
        before { reimbursement_item.stub(:exchange_inventory_unit).and_return(mock_model(Spree::InventoryUnit)) }
        it { expect(subject).to be_nil }
      end

      context "no exchange inventory unit exists" do
        it "builds a pending inventory unit with references to the reimbursement item, variant, and previous inventory unit" do
          expect(subject.variant).to eq reimbursement_item.exchange_variant
          expect(subject.pending).to eq true
          expect(subject).not_to be_persisted
          expect(subject.original_reimbursement_item).to eq reimbursement_item
          expect(subject.line_item).to eq reimbursement_item.inventory_unit.line_item
        end
      end
    end

    context "the reimbursement item is not intended to be exchanged" do
      it { expect(subject).to be_nil }
    end
  end

  describe "#eligible_exchange_variants" do
    it "uses the exchange variant calculator to compute possible variants to exchange for" do
      return_item = build(:return_item)
      expect(Spree::ReturnItem.exchange_variant_engine).to receive(:eligible_variants).with(return_item.variant)
      return_item.eligible_exchange_variants
    end
  end

end
