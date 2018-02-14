require 'spec_helper'

describe Spree::TaxonsController, type: :controller do
  it 'provides the current user to the searcher class' do
    taxon = create(:taxon, permalink: 'test')
    user = mock_model(Spree.user_class, last_incomplete_spree_order: nil, spree_api_key: 'fake')
    allow(controller).to receive_messages spree_current_user: user
    expect_any_instance_of(Spree::Config.searcher_class).to receive(:current_user=).with(user)
    spree_get :show, id: taxon.permalink
    expect(response.status).to eq(200)
  end
end
