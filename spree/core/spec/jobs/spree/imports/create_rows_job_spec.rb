require 'spec_helper'

RSpec.describe Spree::Imports::CreateRowsJob, type: :job do
  let(:import) { create(:import, owner: @default_store, type: 'Spree::Imports::Products', status: :completed_mapping) }

  it 'warns and delegates to ProcessJob' do
    expect(Spree::Deprecation).to receive(:warn).with(/CreateRowsJob is deprecated/)
    expect(Spree::Imports::ProcessJob).to receive(:perform_now).with(import.id)

    described_class.perform_now(import.id)
  end
end
