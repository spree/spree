require 'spec_helper'

# A seller's offers on the marketplace's master-catalog products
# (docs/plans/6.0-seller-master-catalog-listings.md).
RSpec.describe Spree::Api::V3::Seller::VariantsController, type: :controller do
  render_views

  include_context 'API v3 Seller'

  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end
  let(:token) do
    Spree::Api::V3::TestingSupport.generate_jwt(
      seller_user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER
    )
  end

  let!(:master) do
    create(:product, name: 'Shared Lamp', store: store, status: 'active', open_to_sellers: true)
  end
  let(:other_seller) { create(:seller, :approved, store: store) }
  let!(:my_offer) { create(:variant, product: master, seller: seller, sku: 'MINE-1', status: 'draft') }
  let!(:their_offer) { create(:variant, product: master, seller: other_seller, sku: 'THEIRS-1') }
  let!(:location) { create(:stock_location, store: store, seller: seller) }

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  describe 'GET #index' do
    it "lists only this seller's offers" do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].pluck('sku')).to contain_exactly('MINE-1')
    end

    it 'names the product each offer sits on' do
      get :index, as: :json

      expect(json_response['data'].first['product_id']).to eq(master.prefixed_id)
    end

    it 'lists this seller\'s offers on one product when nested' do
      get :index, params: { master_product_id: master.prefixed_id }, as: :json

      expect(json_response['data'].pluck('sku')).to contain_exactly('MINE-1')
    end
  end

  describe 'GET #show' do
    it 'serializes the offer with its status' do
      get :show, params: { id: my_offer.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['sku']).to eq('MINE-1')
      expect(json_response['status']).to be_present
    end

    # A rival's row must be indistinguishable from one that does not exist.
    it "404s another seller's offer" do
      get :show, params: { id: their_offer.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    let(:payload) do
      {
        master_product_id: master.prefixed_id,
        sku: 'NEW-OFFER-1',
        prices: [{ amount: '9.99', currency: 'USD' }],
        stock_levels: [{ stock_location_id: location.prefixed_id, count_on_hand: 3 }]
      }
    end

    it 'lists an offer against the master product' do
      post :create, params: payload, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['sku']).to eq('NEW-OFFER-1')
    end

    # The row carries the seller from the scope it was built in, never from
    # the payload.
    it 'owns the offer whatever the payload claims' do
      post :create, params: payload.merge(seller_id: other_seller.prefixed_id), as: :json

      created = Spree::Variant.find_by(sku: 'NEW-OFFER-1')
      expect(created.seller).to eq(seller)
    end

    # An offer goes on sale by being approved, so it can never be created
    # already active.
    it 'opens the offer as a draft' do
      post :create, params: payload.merge(status: 'active'), as: :json

      expect(Spree::Variant.find_by(sku: 'NEW-OFFER-1')).to be_draft
    end

    it 'refuses a product the operator has not opened' do
      master.update!(open_to_sellers: false)

      post :create, params: payload, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'refuses a product another seller owns' do
      owned = create(:product, store: store, status: 'active', seller: other_seller, open_to_sellers: true)

      post :create, params: payload.merge(master_product_id: owned.prefixed_id), as: :json

      expect(response).to have_http_status(:not_found)
    end

    # Stock belongs to the warehouse it sits in, and the model would resolve a
    # location against the whole store. Refused rather than dropped: a 200
    # that quietly wrote no stock would leave a seller believing they stocked
    # something they did not.
    it "404s a stock level in another seller's warehouse" do
      theirs = create(:stock_location, store: store, seller: other_seller)

      post :create, params: payload.merge(
        stock_levels: [{ stock_location_id: theirs.prefixed_id, count_on_hand: 5 }]
      ), as: :json

      expect(response).to have_http_status(:not_found)
      expect(Spree::Variant.find_by(sku: 'NEW-OFFER-1')).to be_nil
    end

    context 'with option types on the master product' do
      let(:condition) { create(:option_type, name: 'condition', label: 'Condition') }
      let!(:used) { create(:option_value, option_type: condition, name: 'used', label: 'Used') }

      before { master.option_types << condition }

      it 'accepts a value the product already carries' do
        post :create, params: payload.merge(options: [{ name: 'condition', value: 'used' }]), as: :json

        expect(response).to have_http_status(:created)
        expect(Spree::Variant.find_by(sku: 'NEW-OFFER-1').option_values).to include(used)
      end

      # The axis is the vocabulary, not the values other variants happen to
      # have taken. Resolving against the product's own `option_values` (the
      # values its existing variants use) would refuse exactly the ones a
      # seller needs, since one offer per combination means a new offer
      # usually names a combination nobody has listed yet.
      it 'accepts a value on the axis that no existing variant uses' do
        unused = create(:option_value, option_type: condition, name: 'refurbished', label: 'Refurbished')

        expect(master.option_values.reload).not_to include(unused)

        post :create, params: payload.merge(options: [{ name: 'condition', value: 'refurbished' }]), as: :json

        expect(response).to have_http_status(:created)
        expect(Spree::Variant.find_by(sku: 'NEW-OFFER-1').option_values).to include(unused)
      end

      # set_option_value creates option values on demand, so an unfiltered
      # payload would add a seller's spelling to the marketplace's vocabulary.
      it 'refuses a value the marketplace does not offer' do
        expect {
          post :create, params: payload.merge(options: [{ name: 'condition', value: 'pristine' }]), as: :json
        }.not_to change(Spree::OptionValue, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('unknown_option_value')
      end

      # set_option_value looks an option type up globally and attaches it to
      # the product, so this would add an axis to the operator's listing.
      it 'refuses an axis the product is not sold by' do
        expect {
          post :create, params: payload.merge(
            options: [{ name: 'condition', value: 'used' }, { name: 'voltage', value: '240v' }]
          ), as: :json
        }.not_to change(Spree::OptionType, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('unknown_option_type')
      end

      # A row missing the condition axis would land in the wrong buy box.
      it 'refuses an offer that names no value for an axis' do
        post :create, params: payload, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('missing_option_value')
      end

      it 'refuses a second offer in the same combination' do
        post :create, params: payload.merge(options: [{ name: 'condition', value: 'used' }]), as: :json
        expect(response).to have_http_status(:created)

        post :create, params: payload.merge(
          sku: 'NEW-OFFER-2', options: [{ name: 'condition', value: 'used' }]
        ), as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('duplicate_offer')
      end

      # Two sellers listing the same condition is the whole point of a shared
      # catalog.
      it "allows the same combination as another seller's offer" do
        their_offer.option_values << used

        post :create, params: payload.merge(options: [{ name: 'condition', value: 'used' }]), as: :json

        expect(response).to have_http_status(:created)
      end
    end
  end

  describe 'PATCH #update' do
    it 'edits the offer' do
      patch :update, params: { id: my_offer.prefixed_id, sku: 'MINE-EDITED' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(my_offer.reload.sku).to eq('MINE-EDITED')
    end

    it "404s another seller's offer" do
      patch :update, params: { id: their_offer.prefixed_id, sku: 'HIJACK' }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(their_offer.reload.sku).to eq('THEIRS-1')
    end

    # Status is not a writable attribute here: an offer goes on sale by being
    # approved, and a plain write would record no decision.
    it 'ignores a status in the payload' do
      patch :update, params: { id: my_offer.prefixed_id, status: 'active' }, as: :json

      expect(my_offer.reload).to be_draft
    end

    it 'ignores a seller in the payload' do
      patch :update, params: { id: my_offer.prefixed_id, seller_id: other_seller.prefixed_id }, as: :json

      expect(my_offer.reload.seller).to eq(seller)
    end
  end

  describe 'DELETE #destroy' do
    it 'withdraws the offer' do
      delete :destroy, params: { id: my_offer.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(my_offer.reload).to be_deleted
    end

    it "404s another seller's offer" do
      delete :destroy, params: { id: their_offer.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(their_offer.reload).not_to be_deleted
    end
  end

  describe 'status actions' do
    before { my_offer.set_price('USD', 12) }

    it 'submits an offer for review' do
      patch :submit, params: { id: my_offer.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(my_offer.reload).to be_proposed
    end

    it 'records who submitted it' do
      patch :submit, params: { id: my_offer.prefixed_id }, as: :json

      expect(my_offer.reload.latest_submission.submitted_by).to eq(seller_user)
    end

    it 'takes an offer back down' do
      Spree.variant_propose_workflow.call(variant: my_offer)

      patch :draft, params: { id: my_offer.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(my_offer.reload).to be_draft
    end

    it 'archives an offer' do
      patch :archive, params: { id: my_offer.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(my_offer.reload).to be_archived
    end

    it 'refuses an offer with no price' do
      my_offer.prices.destroy_all

      patch :submit, params: { id: my_offer.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(my_offer.reload).to be_draft
    end

    it "404s another seller's offer" do
      patch :submit, params: { id: their_offer.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    # There is no route onto `active`: reaching it is the operator's decision.
    it 'offers no way for a seller to activate' do
      expect {
        patch :activate, params: { id: my_offer.prefixed_id }, as: :json
      }.to raise_error(ActionController::UrlGenerationError)
    end
  end

  context 'without write_products' do
    let(:narrow_role) { create(:role, name: 'Viewer', resource: seller, permissions: %w[read_products]) }
    let(:seller_user) do
      create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user, narrow_role) }
    end

    it 'refuses to create an offer' do
      post :create, params: { master_product_id: master.prefixed_id, sku: 'NOPE' }, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it 'refuses to submit one' do
      patch :submit, params: { id: my_offer.prefixed_id }, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it 'still lists them' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
    end
  end
end
