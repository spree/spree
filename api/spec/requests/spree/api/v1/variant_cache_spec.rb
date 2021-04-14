require 'spec_helper'

describe 'Variant cache', type: :request, caching: true do
  let!(:user)  { create(:admin_user).tap {|u| u.generate_spree_api_key!} }
  subject { create(:variant).tap {|v| v.stock_items.first.set_count_on_hand(10)}}

  before do
    allow_any_instance_of(Spree::StockItem).to receive_messages(backorderable: false)
  end

  it 'correctly shows a cached version when the cache key does not change' do
    subject.update(:weight => 20)
    expect(subject.weight.to_i).to be(20)

    get "/api/v1/variants/#{subject.id}", params: { token: user.spree_api_key }
    expect(response.status).to eq(200)
    response_a = response.body

    subject.update_column(:weight, 5) # update_column to not trigger a cache key/version change
    expect(subject.weight.to_i).to be(5)

    get "/api/v1/variants/#{subject.id}", params: { token: user.spree_api_key }
    expect(response.status).to eq(200)
    response_b = response.body

    expect(response_a).to eq(response_b)
  end

  context 'with cache versioning turned on' do
    before do
      Spree::Variant.collection_cache_versioning = true
      Spree::Variant.cache_versioning = true

      expect(Spree::Variant.cache_versioning).to be_truthy
      expect(Spree::Variant.collection_cache_versioning).to be_truthy
    end

    context 'without stock' do
      before { subject.stock_items.first.set_count_on_hand(0) }

      it 'returns an out of stock response' do
        get "/api/v1/variants/#{subject.id}", params: { token: user.spree_api_key }
        expect(response.status).to eq(200)

        variant = JSON.parse(response.body)

        expect(variant['stock_items'].size).to eq(1)
        expect(variant['total_on_hand']).to be(0)
        expect(variant['is_orderable']).to be_falsey
        expect(variant['is_backorderable']).to be_falsey
        expect(variant['in_stock']).to be_falsey
      end
    end

    context 'with stock' do
      before { subject.stock_items.first.set_count_on_hand(5) }

      it 'returns a positive in stock response' do
        get "/api/v1/variants/#{subject.id}", params: { token: user.spree_api_key }
        expect(response.status).to eq(200)

        variant = JSON.parse(response.body)

        expect(variant['stock_items'].size).to eq(1)
        expect(variant['total_on_hand']).to be(5)
        expect(variant['is_orderable']).to be_truthy
        expect(variant['is_backorderable']).to be_falsey
        expect(variant['in_stock']).to be_truthy
      end
    end
  end


  context 'with cache versioning turned off' do
    before do
      Spree::Variant.collection_cache_versioning = false
      Spree::Variant.cache_versioning = false

      expect(Spree::Variant.cache_versioning).to be_falsey
      expect(Spree::Variant.collection_cache_versioning).to be_falsey
    end

    context 'without stock' do
      before { subject.stock_items.first.set_count_on_hand(0) }

      it 'returns an out of stock response' do
        get "/api/v1/variants/#{subject.id}", params: { token: user.spree_api_key }
        expect(response.status).to eq(200)

        variant = JSON.parse(response.body)

        expect(variant['stock_items'].size).to eq(1)
        expect(variant['total_on_hand']).to be(0)
        expect(variant['is_orderable']).to be_falsey
        expect(variant['is_backorderable']).to be_falsey
        expect(variant['in_stock']).to be_falsey
      end
    end

    context 'with stock' do
      before { subject.stock_items.first.set_count_on_hand(5) }

      it 'returns a positive in stock response' do
        get "/api/v1/variants/#{subject.id}", params: { token: user.spree_api_key }
        expect(response.status).to eq(200)

        variant = JSON.parse(response.body)

        expect(variant['stock_items'].size).to eq(1)
        expect(variant['total_on_hand']).to be(5)
        expect(variant['is_orderable']).to be_truthy
        expect(variant['is_backorderable']).to be_falsey
        expect(variant['in_stock']).to be_truthy
      end
    end
  end
end
