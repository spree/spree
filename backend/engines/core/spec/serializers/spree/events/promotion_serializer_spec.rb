# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::PromotionSerializer do
  let(:promotion) do
    create(:promotion,
           name: 'Test Promotion',
           code: 'SAVE10',
           starts_at: 1.day.ago,
           expires_at: 1.month.from_now)
  end

  subject { described_class.serialize(promotion) }

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(promotion.prefix_id)
      expect(subject[:name]).to eq('Test Promotion')
    end

    it 'includes code' do
      expect(subject).to have_key(:code)
    end

    it 'includes description' do
      expect(subject).to have_key(:description)
    end

    it 'includes type and kind' do
      expect(subject).to have_key(:type)
      expect(subject).to have_key(:kind)
    end

    it 'includes policy settings' do
      expect(subject).to have_key(:match_policy)
      expect(subject).to have_key(:usage_limit)
      expect(subject).to have_key(:advertise)
      expect(subject).to have_key(:path)
    end

    it 'includes multi-code settings' do
      expect(subject).to have_key(:multi_codes)
      expect(subject).to have_key(:code_prefix)
      expect(subject).to have_key(:number_of_codes)
    end

    it 'includes date range' do
      expect(subject[:starts_at]).to be_present
      expect(subject[:expires_at]).to be_present
    end

    it 'includes promotion_category_id' do
      expect(subject).to have_key(:promotion_category_id)
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end
  end
end
