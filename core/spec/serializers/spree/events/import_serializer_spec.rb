# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::ImportSerializer do
  let(:store) { @default_store }
  let(:admin_user) { create(:admin_user) }
  let(:import) { create(:import, owner: store, user: admin_user) }

  subject { described_class.serialize(import) }

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(import.prefix_id)
      expect(subject[:number]).to eq(import.number)
    end

    it 'includes type' do
      expect(subject[:type]).to be_present
    end

    it 'includes status as string' do
      expect(subject[:status]).to be_a(String)
    end

    it 'includes owner polymorphic reference' do
      expect(subject[:owner_type]).to eq('Spree::Store')
      expect(subject[:owner_id]).to eq(store.prefix_id)
    end

    it 'includes user_id' do
      expect(subject[:user_id]).to eq(admin_user.prefix_id)
    end

    it 'includes rows_count' do
      expect(subject).to have_key(:rows_count)
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end
  end
end
