require 'spec_helper'

module Spree
  describe ImportService::Create, import: true do
    subject(:service) { described_class.new(csv_file: file, user_id: user_id, store_id: store_id, type: type) }

    let(:file) { file_fixture('import/products_valid.csv') }
    let(:user_id) { create(:user).id }
    let(:store_id) { create(:store).id }
    let(:type) { 'Spree::Imports::Products' }

    context 'with valid params' do
      it 'creates import record' do
        expect { service.call }.to change(Spree::Import, :count).by(1)
      end
    end

    context 'with invalid params' do
      context 'with file with another format' do
        let(:file) { file_fixture('icon_256x256.gif') }

        it 'does not create import' do
          expect { service.call }.to_not change(Spree::Import, :count)
        end

        it 'returns errors' do
          service.call
          
          expect(service.errors).to include('invalid format')
        end
      end

      context 'with valid CSV file with invalid headers' do
        let(:file) { file_fixture('import/products_invalid_headers.csv') }

        it 'does not create import' do
          expect { service.call }.to_not change(Spree::Import, :count)
        end

        it 'returns errors' do
          service.call
          
          expect(service.errors).to include('missing headers: sku')
        end
      end

      context 'without store_id' do
        let(:store_id) { nil }

        it 'does not create import' do
          expect { service.call }.to_not change(Spree::Import, :count)
        end

        it 'returns errors' do
          service.call
          
          expect(service.errors).to include("Validation failed: Store can't be blank")
        end
      end
    end
  end
end
