# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::StoreCreditSerializer do
  let(:store) { create(:store) }
  let(:user) { create(:user) }
  let(:admin_user) { create(:admin_user) }
  let(:store_credit) do
    create(:store_credit,
           user: user,
           created_by: admin_user,
           amount: 100.00,
           currency: 'USD',
           store: store)
  end

  subject { described_class.serialize(store_credit) }

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(store_credit.id)
    end

    it 'includes amount fields' do
      expect(subject[:amount]).to eq(100.00)
      expect(subject).to have_key(:amount_used)
      expect(subject).to have_key(:amount_authorized)
      expect(subject[:currency]).to eq('USD')
    end

    it 'includes memo' do
      expect(subject).to have_key(:memo)
    end

    it 'includes user foreign keys' do
      expect(subject[:user_id]).to eq(user.id)
      expect(subject[:created_by_id]).to eq(admin_user.id)
    end

    it 'includes category and type ids' do
      expect(subject).to have_key(:category_id)
      expect(subject).to have_key(:type_id)
    end

    it 'includes store_id' do
      expect(subject[:store_id]).to eq(store.id)
    end

    it 'includes originator polymorphic reference' do
      expect(subject).to have_key(:originator_type)
      expect(subject).to have_key(:originator_id)
    end

    it 'includes deleted_at' do
      expect(subject).to have_key(:deleted_at)
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end
  end
end
