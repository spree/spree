require 'spec_helper'

RSpec.describe Spree::Variants::TouchJob, type: :job do
  let(:variant1) { create(:variant) }
  let(:variant2) { create(:variant) }

  before do
    variant1.update_column(:updated_at, 1.day.ago)
    variant2.update_column(:updated_at, 1.day.ago)
  end

  it 'touches all variants with the given IDs' do
    original_updated_at1 = variant1.reload.updated_at
    original_updated_at2 = variant2.reload.updated_at

    described_class.perform_now([variant1.id, variant2.id])

    expect(variant1.reload.updated_at).to be > original_updated_at1
    expect(variant2.reload.updated_at).to be > original_updated_at2
  end

  it 'handles empty array' do
    expect { described_class.perform_now([]) }.not_to raise_error
  end
end
