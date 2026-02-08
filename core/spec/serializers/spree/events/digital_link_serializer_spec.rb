# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::DigitalLinkSerializer do
  let(:digital_link) { create(:digital_link) }

  subject { described_class.serialize(digital_link) }

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(digital_link.prefix_id)
    end

    it 'includes foreign keys' do
      expect(subject[:digital_id]).to eq(digital_link.digital&.prefix_id)
      expect(subject[:line_item_id]).to eq(digital_link.line_item&.prefix_id)
    end

    it 'includes access_counter' do
      expect(subject).to have_key(:access_counter)
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end
  end
end
