require 'spec_helper'

RSpec.describe SpreeVies::RevalidateJob do
  it 'queues a check for every number due one, leaving its verdict in place' do
    stale = create(:tax_identifier)
    stale.update_columns(validation_status: 'verified', validated_at: 91.days.ago)
    fresh = create(:tax_identifier)
    fresh.update_columns(validation_status: 'verified', validated_at: 1.day.ago)

    described_class.perform_now

    expect(Spree::TaxIdentifiers::ValidateJob).to have_been_enqueued.with(stale.id).exactly(:once)
    expect(Spree::TaxIdentifiers::ValidateJob).not_to have_been_enqueued.with(fresh.id)

    expect(stale.reload.validation_status).to eq('verified')
  end
end
