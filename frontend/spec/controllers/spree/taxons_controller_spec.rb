require 'spec_helper'

describe Spree::TaxonsController, :type => :controller do
  it "should provide the current user to the searcher class" do
    taxon = create(:taxon, :permalink => "test")
    user = mock_model(Spree.user_class, :last_incomplete_spree_order => nil, :spree_api_key => 'fake')
    allow(controller).to receive_messages :spree_current_user => user
    expect_any_instance_of(Spree::Config.searcher_class).to receive(:current_user=).with(user)
    spree_get :show, :id => taxon.permalink
    expect(response.status).to eq(200)
  end

  context 'with history slugs present' do
    let(:taxon) { create(:taxon, permalink: "old-slug") }

    before do
      @legacy_params = taxon.to_param
      taxon.update_attributes(permalink: "new-slug")
    end

    it 'will redirect with a 301 with legacy url used' do
      spree_get :show, id: @legacy_params
      expect(response.status).to eq(301)
    end

    it 'will redirect with a 301 with id used' do
      spree_get :show, id: taxon.id
      expect(response.status).to eq(301)
    end

    it "will keep url params on legacy url redirect" do
      spree_get :show, id: @legacy_params, taxon_id: taxon.id
      expect(response.status).to eq(301)
      expect(response.header["Location"]).to include("taxon_id=#{taxon.id}")
    end
  end
end
