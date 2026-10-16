require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Carts::AddressesController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:cart) { create(:cart_with_line_items, customer: user, store: store) }
  let!(:own_address) { create(:address, customer: user) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  def listed_ids
    json_response['data'].map { |address| address['id'] }
  end

  describe 'GET #index' do
    it 'lists the buyer\'s own book' do
      get :index, params: { cart_id: cart.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(listed_ids).to include(own_address.prefixed_id)
      expect(listed_ids).to match_array(user.addresses.map(&:prefixed_id))
    end

    it 'leaves out another customer\'s book' do
      foreign = create(:address, customer: create(:user))

      get :index, params: { cart_id: cart.prefixed_id }

      expect(listed_ids).not_to include(foreign.prefixed_id)
    end

    context 'when the cart is for a company' do
      let(:company) { create(:company, store: store) }
      let(:division) { create(:company, store: store, kind: 'division', parent: company) }
      let!(:headquarters) { create(:company_address, owner: company, first_name: 'Dana', last_name: 'Reyes') }
      let!(:site) { create(:company_address, owner: division, first_name: 'Sam', last_name: 'Okafor') }

      before do
        create(:company_membership, company: company, customer: user)
        cart.update!(company: division)
      end

      it 'adds the node\'s own sites and the ones it inherits' do
        get :index, params: { cart_id: cart.prefixed_id }

        expect(listed_ids).to include(own_address.prefixed_id, headquarters.prefixed_id, site.prefixed_id)
      end

      it 'leaves out a company the cart is not for' do
        outsider = create(:company_address, owner: create(:company, store: store))

        get :index, params: { cart_id: cart.prefixed_id }

        expect(listed_ids).not_to include(outsider.prefixed_id)
      end
    end

    it 'refuses a cart belonging to another customer' do
      other_cart = create(:cart, store: store, customer: create(:user))

      get :index, params: { cart_id: other_cart.prefixed_id }

      expect(response).to have_http_status(:forbidden).or have_http_status(:not_found)
    end
  end
end
