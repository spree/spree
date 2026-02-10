require 'spec_helper'

RSpec.describe Spree::Seeds::ReturnsEnvironment do
  subject { described_class.call }

  describe 'RefundReason' do
    it 'creates a Return processing RefundReason' do
      expect { subject }.to change { Spree::RefundReason.where(name: 'Return processing', mutable: false).count }.by(1)
    end

    context 'when the RefundReason already exists' do
      before do
        Spree::RefundReason.create!(name: 'Return processing', mutable: false)
      end

      it "doesn't create a new RefundReason" do
        expect { subject }.not_to change(Spree::RefundReason, :count)
      end
    end
  end

  describe 'ReturnAuthorizationReason' do
    let(:expected_reasons) do
      [
        'Better price available',
        'Missed estimated delivery date',
        'Missing parts or accessories',
        'Damaged/Defective',
        'Different from what was ordered',
        'Different from description',
        'No longer needed/wanted',
        'Accidental order',
        'Unauthorized purchase'
      ]
    end

    it 'creates all ReturnAuthorizationReasons' do
      expect { subject }.to change(Spree::ReturnAuthorizationReason, :count).by(expected_reasons.count)

      expected_reasons.each do |reason|
        expect(Spree::ReturnAuthorizationReason.find_by(name: reason)).to be_present
      end
    end

    context 'when ReturnAuthorizationReasons already exist' do
      before do
        expected_reasons.each do |reason|
          Spree::ReturnAuthorizationReason.create!(name: reason)
        end
      end

      it "doesn't create new ReturnAuthorizationReasons" do
        expect { subject }.not_to change(Spree::ReturnAuthorizationReason, :count)
      end
    end
  end

  describe 'ReimbursementType' do
    let(:expected_types) do
      [
        { name: 'Store Credit', type: 'Spree::ReimbursementType::StoreCredit' },
        { name: 'Exchange', type: 'Spree::ReimbursementType::Exchange' },
        { name: 'Original payment', type: 'Spree::ReimbursementType::OriginalPayment' }
      ]
    end

    it 'creates all ReimbursementTypes' do
      expect { subject }.to change(Spree::ReimbursementType, :count).by(expected_types.count)

      expected_types.each do |type_attrs|
        reimbursement_type = Spree::ReimbursementType.find_by(name: type_attrs[:name])
        expect(reimbursement_type).to be_present
        expect(reimbursement_type.type).to eq(type_attrs[:type])
      end
    end

    context 'when ReimbursementTypes already exist' do
      before do
        expected_types.each do |type_attrs|
          Spree::ReimbursementType.create!(name: type_attrs[:name], type: type_attrs[:type])
        end
      end

      it "doesn't create new ReimbursementTypes" do
        expect { subject }.not_to change(Spree::ReimbursementType, :count)
      end
    end
  end
end
