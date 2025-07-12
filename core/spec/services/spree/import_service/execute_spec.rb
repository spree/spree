require 'spec_helper'

module Spree
  describe ImportService::Execute, import: true do
    subject(:service) { described_class.new(import: import) }

    let(:import) { create(:import, attachment: file) }
    let(:file) { file_fixture('import/products_valid.csv') }

    let(:product_upsert_klass) { Spree::ImportService::Products::Upsert }
    let(:product_upsert_instance) { double(call: true) }

    before do
      allow(product_upsert_klass).to receive(:new).and_return(product_upsert_instance)
    end

    it 'calls Products::Upsert for each row' do
      expect(product_upsert_instance).to receive(:call).twice
      
      service.call
    end
  end
end
