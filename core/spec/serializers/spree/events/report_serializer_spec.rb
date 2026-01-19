# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::ReportSerializer do
  subject { described_class.serialize(report) }

  let(:store) { @default_store }
  let(:user) { create(:admin_user) }
  let(:report) do
    create(:report,
      store: store,
      user: user,
      date_from: 1.month.ago,
      date_to: Time.current,
      currency: 'USD'
    )
  end

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(report.id)
      expect(subject[:type]).to eq(report.type)
    end

    it 'includes store reference' do
      expect(subject[:store_id]).to eq(store.id)
    end

    it 'includes user reference' do
      expect(subject[:user_id]).to eq(user.id)
    end

    it 'includes currency' do
      expect(subject[:currency]).to eq('USD')
    end

    it 'includes date range' do
      expect(subject[:date_from]).to be_present
      expect(subject[:date_to]).to be_present
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end
  end
end
