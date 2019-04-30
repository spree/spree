require 'spec_helper'

describe Spree::ProductsController, type: :controller do
  let!(:product) { create(:product, available_on: 1.year.from_now) }
  let(:taxon) { create(:taxon) }

  # Regression test for #1390
  it 'allows admins to view non-active products' do
    allow(controller).to receive_messages spree_current_user: mock_model(Spree.user_class, has_spree_role?: true, last_incomplete_spree_order: nil, spree_api_key: 'fake')
    get :show, params: { id: product.to_param }
    expect(response.status).to eq(200)
  end

  it 'cannot view non-active products' do
    expect { get :show, params: { id: product.to_param } }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it 'provides the current user to the searcher class' do
    user = mock_model(Spree.user_class, last_incomplete_spree_order: nil, spree_api_key: 'fake')
    allow(controller).to receive_messages spree_current_user: user
    expect_any_instance_of(Spree::Config.searcher_class).to receive(:current_user=).with(user)
    get :index
    expect(response.status).to eq(200)
  end

  # Regression test for #2249
  it "doesn't error when given an invalid referer" do
    current_user = mock_model(Spree.user_class, has_spree_role?: true, last_incomplete_spree_order: nil, generate_spree_api_key!: nil)
    allow(controller).to receive_messages spree_current_user: current_user
    request.env['HTTP_REFERER'] = 'not|a$url'

    # Previously a URI::InvalidURIError exception was being thrown
    expect { get :show, params: { id: product.to_param } }.not_to raise_error
  end

  context 'with history slugs present' do
    let!(:product) { create(:product, available_on: 1.day.ago) }

    it 'will redirect with a 301 with legacy url used' do
      legacy_params = product.to_param
      product.name = product.name + ' Brand New'
      product.slug = nil
      product.save!
      get :show, params: { id: legacy_params }
      expect(response.status).to eq(301)
    end

    it 'will redirect with a 301 with id used' do
      product.name = product.name + ' Brand New'
      product.slug = nil
      product.save!
      get :show, params: { id: product.id }
      expect(response.status).to eq(301)
    end

    it 'will keep url params on legacy url redirect' do
      legacy_params = product.to_param
      product.name = product.name + ' Brand New'
      product.slug = nil
      product.save!
      get :show, params: { id: legacy_params, taxon_id: taxon.id }
      expect(response.status).to eq(301)
      expect(response.header['Location']).to include("taxon_id=#{taxon.id}")
    end
  end

  context 'index products' do
    it 'calls includes when the retrieved_products object responds to it' do
      searcher = double('Searcher')
      allow(controller).to receive_messages build_searcher: searcher
      expect(searcher).to receive_message_chain('retrieve_products.includes')

      get :index
    end

    it "does not call includes when it's not available" do
      searcher = double('Searcher')
      allow(controller).to receive_messages build_searcher: searcher
      allow(searcher).to receive(:retrieve_products).and_return([])

      get :index

      expect(assigns(:products)).to eq([])
    end
  end
end
