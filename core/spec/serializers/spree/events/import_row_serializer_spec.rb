# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::ImportRowSerializer do
  subject { described_class.serialize(import_row) }

  let(:store) { @default_store }
  let(:user) { create(:admin_user) }
  let(:import) { create(:import, owner: store, user: user) }
  let(:product) { create(:product) }
  let(:import_row) do
    create(:import_row,
      import: import,
      row_number: 1,
      status: 'completed',
      item: product,
      validation_errors: nil
    )
  end

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(import_row.id)
    end

    it 'includes import reference' do
      expect(subject[:import_id]).to eq(import.id)
    end

    it 'includes row_number' do
      expect(subject[:row_number]).to eq(1)
    end

    it 'includes status' do
      expect(subject[:status]).to eq('completed')
    end

    it 'includes validation_errors' do
      expect(subject).to have_key(:validation_errors)
    end

    it 'includes item polymorphic reference' do
      expect(subject[:item_type]).to eq('Spree::Product')
      expect(subject[:item_id]).to eq(product.id)
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end

    context 'with validation errors' do
      let(:import_row) do
        create(:import_row,
          import: import,
          row_number: 2,
          status: 'failed',
          validation_errors: 'Name is required'
        )
      end

      it 'includes validation error message' do
        expect(subject[:validation_errors]).to eq('Name is required')
        expect(subject[:status]).to eq('failed')
      end
    end
  end
end
