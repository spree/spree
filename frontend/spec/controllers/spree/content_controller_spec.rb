require 'spec_helper'
describe Spree::ContentController, type: :controller do
  it 'should display CVV page' do
    spree_get :cvv
    expect(response.response_code).to eq(200)
  end
end
