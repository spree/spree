require 'spec_helper'

RSpec.describe Spree::Imports::Customers, type: :model do
  let(:store) { Spree::Store.default }
  let(:import) { create(:customer_import, owner: store) }

  describe '#row_processor_class' do
    it 'returns Customer row processor' do
      expect(import.row_processor_class).to eq Spree::Imports::RowProcessors::Customer
    end
  end

  describe '#model_class' do
    it 'returns the user class' do
      expect(import.model_class).to eq Spree.user_class
    end
  end

  describe '#import_schema' do
    it 'returns the customers import schema' do
      expect(import.import_schema).to be_a(Spree::ImportSchemas::Customers)
    end
  end
end
