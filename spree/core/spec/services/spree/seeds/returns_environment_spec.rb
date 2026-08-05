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

  describe 'ReturnReason' do
    let(:expected_reasons) { described_class::RETURN_REASONS }

    it 'creates all ReturnReasons' do
      expect { subject }.to change(Spree::ReturnReason, :count).by(expected_reasons.count)

      expected_reasons.each do |reason|
        expect(Spree::ReturnReason.find_by(name: reason)).to be_present
      end
    end

    context 'when ReturnReasons already exist' do
      before do
        expected_reasons.each { |reason| Spree::ReturnReason.create!(name: reason) }
      end

      it "doesn't create new ReturnReasons" do
        expect { subject }.not_to change(Spree::ReturnReason, :count)
      end
    end
  end

  describe 'ClaimReason' do
    let(:expected_reasons) { described_class::CLAIM_REASONS }

    it 'creates all ClaimReasons' do
      expect { subject }.to change(Spree::ClaimReason, :count).by(expected_reasons.count)

      expected_reasons.each do |reason|
        expect(Spree::ClaimReason.find_by(name: reason)).to be_present
      end
    end

    context 'when ClaimReasons already exist' do
      before do
        expected_reasons.each { |reason| Spree::ClaimReason.create!(name: reason) }
      end

      it "doesn't create new ClaimReasons" do
        expect { subject }.not_to change(Spree::ClaimReason, :count)
      end
    end
  end
end
