# The battery every host of Spree::Api::V3::Admin::ProductMembership runs —
# categories, collections, catalogs and price lists expose the same uniform
# nested products surface, so its contract is asserted once, against each.
#
# A host spec provides:
#   parent_route_params         — route params naming the parent (e.g. { catalog_id: … })
#   foreign_parent_route_params — the same shape naming another store's parent
#   seed_member(product)        — makes the product a member outside the endpoint
#   member_products             — the parent's current member products, freshly read
RSpec.shared_examples 'a product membership surface' do
  describe 'GET #index' do
    it 'lists the members' do
      member = create(:product, store: store)
      seed_member(member)

      get :index, params: parent_route_params, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |row| row['id'] }).to include(member.prefixed_id)
    end

    it '404s under another store parent' do
      get :index, params: foreign_parent_route_params, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    it 'adds store products in bulk by prefixed id' do
      products = create_list(:product, 2, store: store)

      post :create,
           params: parent_route_params.merge(product_ids: products.map(&:prefixed_id)),
           as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['added_count']).to eq(2)
      expect(member_products).to match_array(products)
    end

    it 'skips ids that are already members' do
      existing = create(:product, store: store)
      seed_member(existing)
      fresh = create(:product, store: store)

      post :create,
           params: parent_route_params.merge(product_ids: [existing, fresh].map(&:prefixed_id)),
           as: :json

      expect(json_response['added_count']).to eq(1)
      expect(member_products).to match_array([existing, fresh])
    end

    # The pre-check can go stale under concurrency, so the count is read back
    # from membership rather than from the request's own intent.
    it 'counts what the write actually added, not what was requested' do
      already = create(:product, store: store)
      seed_member(already)

      post :create,
           params: parent_route_params.merge(product_ids: [already.prefixed_id]),
           as: :json

      expect(json_response['added_count']).to eq(0)
      expect(member_products).to contain_exactly(already)
    end

    it 'silently drops products of another store' do
      foreign = create(:product, store: create(:store))

      post :create,
           params: parent_route_params.merge(product_ids: [foreign.prefixed_id]),
           as: :json

      expect(json_response['added_count']).to eq(0)
      expect(member_products).to be_empty
    end
  end

  describe 'DELETE #destroy' do
    it 'removes several products in one request' do
      members = create_list(:product, 2, store: store)
      members.each { |product| seed_member(product) }

      delete :destroy,
             params: parent_route_params.merge(product_ids: members.map(&:prefixed_id)),
             as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['removed_count']).to eq(2)
      expect(member_products).to be_empty
    end

    it 'ignores ids that are not members' do
      member = create(:product, store: store)
      seed_member(member)
      outsider = create(:product, store: store)

      delete :destroy,
             params: parent_route_params.merge(product_ids: [member, outsider].map(&:prefixed_id)),
             as: :json

      expect(json_response['removed_count']).to eq(1)
      expect(member_products).to be_empty
    end
  end
end
