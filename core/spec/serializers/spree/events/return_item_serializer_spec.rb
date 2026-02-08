# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::ReturnItemSerializer do
  let(:return_item) { create(:return_item) }

  subject { described_class.serialize(return_item) }

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(return_item.prefix_id)
    end

    it 'includes status fields' do
      expect(subject[:reception_status]).to be_present
      expect(subject[:acceptance_status]).to be_present
    end

    it 'includes amount fields' do
      expect(subject).to have_key(:pre_tax_amount)
      expect(subject).to have_key(:included_tax_total)
      expect(subject).to have_key(:additional_tax_total)
    end

    it 'includes foreign keys' do
      expect(subject[:inventory_unit_id]).to eq(return_item.inventory_unit&.prefix_id)
      expect(subject[:return_authorization_id]).to eq(return_item.return_authorization&.prefix_id)
      expect(subject).to have_key(:customer_return_id)
      expect(subject).to have_key(:reimbursement_id)
      expect(subject).to have_key(:exchange_variant_id)
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end
  end
end
