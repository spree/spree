require 'spec_helper'

# This spec is useful for when we just want to make sure a view is rendering correctly
# Walking through the entire checkout process is rather tedious, don't you think?
describe Spree::CheckoutController, type: :controller do
  render_views
  let(:token) { 'some_token' }
  let(:user) { stub_model(Spree::LegacyUser) }

  before do
    allow(controller).to receive_messages try_spree_current_user: user
  end

  # Regression test for #3246
  context 'when using GBP' do
    before do
      Spree::Config[:currency] = 'GBP'
      FactoryBot.create(:store, default_currency: 'GBP')
    end

    context 'when order is in delivery' do
      before do
        # Using a let block won't acknowledge the currency setting
        # Therefore we just do it like this...
        order = OrderWalkthrough.up_to(:delivery)
        allow(controller).to receive_messages current_order: order
      end

      it 'displays rate cost in correct currency' do
        get :edit
        html = Nokogiri::HTML(response.body)
        expect(html.css('.rate-cost').text).to eq '£10.00'
      end
    end
  end
end
