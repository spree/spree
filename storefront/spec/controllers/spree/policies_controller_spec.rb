require 'spec_helper'

describe Spree::PoliciesController, type: :controller do
  let(:store) { @default_store }

  render_views

  before do
    allow(controller).to receive(:current_store).and_return(store)
  end

  describe 'GET #show' do
    let(:policy) { create(:policy, owner: store) }

    it 'renders the policy' do
      get :show, params: { id: policy.slug }
      expect(response).to be_successful
      expect(response.body).to include(policy.body.to_plain_text)
    end
  end
end
