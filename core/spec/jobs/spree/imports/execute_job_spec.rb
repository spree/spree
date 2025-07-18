require 'spec_helper'

RSpec.describe Spree::Imports::ExecuteJob, type: :job, import: true do
  let(:import) { create(:product_import, attachment: file_fixture('import/products_valid.csv')) }

  before do
    allow(Spree::ImportService::Execute).to receive(:new).with(import: import).and_return(service_instance)
  end

  let(:service_instance) { double(call: true) }

  describe '#perform' do
    subject(:perform_job) { described_class.perform_now(import.id) }

    it 'calls execute service' do
      expect(service_instance).to receive(:call)

      perform_job
    end
  end
end
