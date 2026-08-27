require 'spec_helper'

RSpec.describe Spree::Imports::ProcessRowsJob, type: :job do
  let(:import) { create(:import, store: @default_store, type: 'Spree::Imports::Products', status: :processing) }

  it 'warns and delegates to ProcessJob, skipping row creation' do
    expect(Spree::Deprecation).to receive(:warn).with(/ProcessRowsJob is deprecated/)
    expect(Spree::Imports::ProcessJob).to receive(:perform_now).with(import.id, skip_row_creation: true)

    described_class.perform_now(import.id)
  end
end
