require 'spec_helper'

RSpec.describe Spree::Admin::Orders::UserController, type: :controller do
  stub_authorization!

  let(:order) { create(:order, user: nil, email: nil) }
  let(:user_params) do
    {
      email: 'test@example.com',
      first_name: 'Test',
      last_name: 'User',
      tag_list: ['tag1', 'tag2']
    }
  end

  describe '#create' do
    context 'when user exists' do
      let!(:existing_user) { create(:user, email: user_params[:email]) }

      it 'updates user with new details' do
        post :create, params: { user: user_params, order_id: order.number }, as: :turbo_stream

        expect(order.reload.user).to eq(existing_user)
        expect(order.email).to eq(existing_user.email)

        expect(existing_user.reload.first_name).to eq(user_params[:first_name])
        expect(existing_user.last_name).to eq(user_params[:last_name])
        expect(existing_user.email).to eq(user_params[:email])
        expect(existing_user.tag_list).to eq(user_params[:tag_list])
      end
    end

    context 'when user does not exist' do
      it 'saves user' do
        post :create, params: { user: user_params, order_id: order.number }, as: :turbo_stream

        new_user = Spree.user_class.find_by(email: user_params[:email])

        expect(order.reload.user).to eq(new_user)
        expect(order.email).to eq(new_user.email)

        expect(new_user.reload.first_name).to eq(user_params[:first_name])
        expect(new_user.last_name).to eq(user_params[:last_name])
        expect(new_user.email).to eq(user_params[:email])
        expect(new_user.tag_list).to eq(user_params[:tag_list])
      end
    end
  end

  describe '#update' do
    let!(:existing_user) { create(:user, email: user_params[:email]) }

    it 'associates new user with order' do
      put :update, params: { user_id: existing_user.id, order_id: order.number }, as: :turbo_stream

      expect(order.reload.user).to eq(existing_user)
      expect(order.email).to eq(existing_user.email)
    end
  end

  describe '#destroy' do
    let!(:existing_user) { create(:user, email: user_params[:email]) }

    it 'removes user association from order' do
      order.update(user: existing_user)

      delete :destroy, params: { order_id: order.number }, as: :turbo_stream

      expect(order.reload.user).to be_nil
    end
  end
end
