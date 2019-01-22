require 'spec_helper'

describe Spree::Checkout::Update, type: :service do
  describe '#transform_address_params' do
    let!(:state)              { create(:state) }
    let!(:country)            { state.country }
    let!(:replace_country)    { described_class.new }
    let!(:address) do
      {
        firstname: 'John',
        lastname: 'Doe',
        address1: '7735 Old Georgetown Road',
        city: 'Bethesda',
        phone: '3014445002',
        zipcode: '20814',
        state_id: state.id,
        country_iso: country.iso
      }
    end

    context 'with ship_address order params' do
      let(:order_params) do
        ActionController::Parameters.new(
          order: {
            ship_address_attributes: address
          }
        )
      end
      let(:result) { replace_country.send(:replace_country_iso_with_id, order_params, 'ship') }

      before { result }

      it 'will return hash contain country_id' do
        expect(result[:order][:ship_address_attributes][:country_id]).to eq country.id
      end

      it 'will return hash without country_iso' do
        expect(result[:order][:ship_address_attributes]).not_to include(:country_iso)
      end
    end

    context 'with bill_address order params' do
      let(:order_params) do
        ActionController::Parameters.new(
          order: {
            bill_address_attributes: address
          }
        )
      end
      let(:result) { replace_country.send(:replace_country_iso_with_id, order_params, 'bill') }

      before { result }

      it 'will return hash contain country_id' do
        expect(result[:order][:bill_address_attributes][:country_id]).to eq country.id
      end

      it 'will return hash without country_iso' do
        expect(result[:order][:bill_address_attributes]).not_to include(:country_iso)
      end
    end
  end
end
