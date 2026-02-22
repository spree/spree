require 'spec_helper'

RSpec.describe Spree::Exports::GenerateJob, type: :job do
  let(:store) { @default_store }
  let(:user) { create(:admin_user) }
  let!(:export) { create(:product_export, store: store, user: user, format: 'csv') }

  describe '#perform' do
    subject(:perform_job) { described_class.perform_now(export.id) }

    it 'calls generate on the export' do
      expect_any_instance_of(Spree::Export).to receive(:generate)
      perform_job
    end
  end
end
