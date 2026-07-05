require 'spec_helper'

RSpec.describe Spree::Admin::PoliciesController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { @default_store }

  describe 'GET #index' do
    subject(:index) { get :index }

    it 'renders the list of policies' do
      index

      expect(response).to render_template(:index)
      expect(assigns[:collection]).to contain_exactly(*store.policies)
    end
  end

  describe 'GET #new' do
    subject(:new) { get :new }

    it 'renders the new policy page' do
      new
      expect(response).to render_template(:new)
    end
  end

  describe 'POST #create' do
    subject(:create_policy) { post :create, params: { policy: policy_params } }

    let(:policy_params) do
      {
        name: 'New Privacy Policy',
        body: 'This is our privacy policy content',
        slug: 'new-privacy-policy'
      }
    end

    it 'creates a new policy' do
      expect { create_policy }.to change(Spree::Policy, :count).by(1)

      policy = Spree::Policy.last
      expect(policy.name).to eq('New Privacy Policy')
      expect(policy.body.to_plain_text).to eq('This is our privacy policy content')
      expect(policy.slug).to eq('new-privacy-policy')
      expect(policy.owner).to eq(store)
    end

    context 'when manually passing owner params' do
      let(:policy_params) do
        {
          name: 'New Privacy Policy',
          body: 'This is our privacy policy content',
          slug: 'new-privacy-policy',
          owner_id: 123,
          owner_type: 'Spree::User'
        }
      end

      it 'ignores the given owner params' do
        expect { create_policy }.to change(Spree::Policy, :count).by(1)
        expect(Spree::Policy.last.owner).to eq(store)
      end
    end
  end

  describe 'GET #edit' do
    subject(:edit) { get :edit, params: { id: policy.to_param } }

    let(:policy) { create(:policy, owner: store) }

    it 'renders the edit page' do
      edit
      expect(response).to render_template(:edit)
    end
  end

  describe 'PUT #update' do
    subject(:update_policy) { put :update, params: { id: policy.to_param, policy: policy_params } }

    let!(:policy) { create(:policy, owner: store) }
    let(:policy_params) do
      {
        name: 'Updated Privacy Policy',
        body: 'This is updated privacy policy content',
        slug: 'updated-privacy-policy'
      }
    end

    it 'updates the policy' do
      update_policy
      policy.reload

      expect(policy.name).to eq('Updated Privacy Policy')
      expect(policy.body.to_plain_text).to eq('This is updated privacy policy content')
      expect(policy.slug).to eq('updated-privacy-policy')
      expect(policy.owner).to eq(store)
    end
  end

  describe 'DELETE #destroy' do
    subject(:destroy_policy) { delete :destroy, params: { id: policy.to_param } }

    let!(:policy) { create(:policy, owner: store) }

    it 'destroys the policy' do
      expect { destroy_policy }.to change(Spree::Policy, :count).by(-1)
    end
  end
end
