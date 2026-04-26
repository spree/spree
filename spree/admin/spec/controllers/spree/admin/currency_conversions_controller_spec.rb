# frozen_string_literal: true

require 'spec_helper'

describe Spree::Admin::CurrencyConversionsController, type: :controller do
  stub_authorization!

  describe '#index' do
    it 'returns suggested conversions as JSON' do
      allow(Spree::Admin::FrankfurterCurrencyConversion).to receive(:convert).and_return(
        { 'EUR' => BigDecimal('92.50'), 'GBP' => BigDecimal('79.99') }
      )

      get :index, params: { amount: '100', from: 'USD', to: 'EUR,GBP' }, format: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq(
        'conversions' => { 'EUR' => 92.5, 'GBP' => 79.99 }
      )
    end
  end
end
