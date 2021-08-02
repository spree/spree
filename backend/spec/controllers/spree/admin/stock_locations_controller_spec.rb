require 'spec_helper'

module Spree
  module Admin
    describe StockLocationsController, type: :controller do
      stub_authorization!

      context 'with a default country present' do
        it 'can create a new stock location' do
          get :new
          expect(response).to be_successful
        end
      end
    end
  end
end
