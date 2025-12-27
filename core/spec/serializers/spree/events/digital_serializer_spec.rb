# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::DigitalSerializer do
  let(:variant) { create(:variant) }
  let(:digital) { create(:digital, variant: variant) }

  subject { described_class.serialize(digital) }

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(digital.id)
    end

    it 'includes variant_id' do
      expect(subject[:variant_id]).to eq(variant.id)
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end
  end
end
