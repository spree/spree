# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::ExportSerializer do
  let(:store) { @default_store }
  let(:admin_user) { create(:admin_user) }
  let(:export) { create(:export, store: store, user: admin_user) }

  subject { described_class.serialize(export) }

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(export.prefix_id)
      expect(subject[:number]).to eq(export.number)
    end

    it 'includes type' do
      expect(subject[:type]).to be_present
    end

    it 'includes format' do
      expect(subject).to have_key(:format)
    end

    it 'includes foreign keys' do
      expect(subject[:user_id]).to eq(admin_user.prefix_id)
      expect(subject[:store_id]).to eq(store.prefix_id)
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end
  end
end
