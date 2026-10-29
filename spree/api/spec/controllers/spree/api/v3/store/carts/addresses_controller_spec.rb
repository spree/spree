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

  def owner_of(address)
    json_response['data'].find { |row| row['id'] == address.prefixed_id }['owner']
  end

  describe 'GET #index' do
    it 'lists the buyer\'s own book' do
      get :index, params: { cart_id: cart.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(listed_ids).to include(own_address.prefixed_id)
      expect(listed_ids).to match_array(user.addresses.map(&:prefixed_id))
    end

    # A picker showing both books has to label them, and nothing else in the
    # payload distinguishes a warehouse from somebody's flat.
    it 'names the book each address came out of' do
      get :index, params: { cart_id: cart.prefixed_id }

      expect(owner_of(own_address)).to eq('id' => user.prefixed_id, 'type' => 'customer', 'name' => nil)
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

      # An inherited site belongs to the node above, not to the one the cart
      # is for — so each entry names its own node and a picker can say where
      # a dock actually is, rather than filing the lot under the division.
      it 'names the owning node, not the cart\'s' do
        get :index, params: { cart_id: cart.prefixed_id }

        expect(owner_of(headquarters)).to eq('id' => company.prefixed_id, 'type' => 'company', 'name' => company.name)
        expect(owner_of(site)).to eq('id' => division.prefixed_id, 'type' => 'company', 'name' => division.name)
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

    # What comes back is the account's books, not the cart's own data, so
    # holding the cart is not enough. The attacker's route is a cart they
    # started and the buyer later adopted: the token is not rotated on
    # association, so it would still read everything the buyer has saved.
    context 'without a signed-in customer' do
      before { request.headers['Authorization'] = nil }

      it 'refuses the cart token that matches' do
        request.headers['X-Spree-Token'] = cart.token

        get :index, params: { cart_id: cart.prefixed_id }

        expect(response).to have_http_status(:unauthorized)
        expect(response.body).not_to include(own_address.address1)
      end

      it 'refuses a request carrying nothing but the publishable key' do
        get :index, params: { cart_id: cart.prefixed_id }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
