require 'spec_helper'

RSpec.describe Spree::Admin::Orders::UserController, type: :controller do
  stub_authorization!
  render_views

  let(:order) { create(:order, user: nil, email: nil) }
  let(:user_params) do
    {
      email: 'test@example.com',
      first_name: 'Test',
      last_name: 'User',
      tag_list: ['tag1', 'tag2']
    }
  end

  describe '#new' do
    subject { get :new, params: { order_id: order.to_param } }

    it 'returns a success response' do
      subject
      expect(response).to be_successful
      expect(response).to render_template(:new)
    end

    it 'builds a new user for the order' do
      subject
      expect(assigns(:user)).to be_a_new(Spree.user_class)
    end
  end

  describe '#create' do
    context 'when user exists' do
      let!(:existing_user) { create(:user, email: user_params[:email]) }

      it 'updates user with new details' do
        post :create, params: { user: user_params, order_id: order.to_param }, as: :turbo_stream

        expect(order.reload.user).to eq(existing_user)
        expect(order.email).to eq(existing_user.email)

        expect(existing_user.reload.first_name).to eq(user_params[:first_name])
        expect(existing_user.last_name).to eq(user_params[:last_name])
        expect(existing_user.email).to eq(user_params[:email])
        expect(existing_user.tag_list).to match_array(user_params[:tag_list])
      end

      context 'when user update fails' do
        before do
          allow_any_instance_of(Spree.user_class).to receive(:update).and_return(false)
          allow_any_instance_of(Spree.user_class).to receive_message_chain(:errors, :full_messages, :to_sentence)
            .and_return('Email is invalid')
        end

        it 'responds with error' do
          post :create, params: { user: user_params, order_id: order.to_param }, as: :turbo_stream

          expect(flash[:error]).to be_present
          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    context 'when user does not exist' do
      it 'saves user' do
        post :create, params: { user: user_params, order_id: order.to_param }, as: :turbo_stream

        new_user = Spree.user_class.find_by(email: user_params[:email])

        expect(order.reload.user).to eq(new_user)
        expect(order.email).to eq(new_user.email)

        expect(new_user.reload.first_name).to eq(user_params[:first_name])
        expect(new_user.last_name).to eq(user_params[:last_name])
        expect(new_user.email).to eq(user_params[:email])
        expect(new_user.tag_list).to match_array(user_params[:tag_list])
      end

      context 'when user save fails' do
        it 'responds with error' do
          post :create, params: { user: { email: '' }, order_id: order.to_param }, as: :turbo_stream

          expect(flash[:error]).to be_present
          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end
  end

  describe '#update' do
    let!(:existing_user) { create(:user, email: user_params[:email]) }

    it 'associates new user with order using prefixed ID' do
      put :update, params: { user_id: existing_user.to_param, order_id: order.to_param }, as: :turbo_stream

      expect(order.reload.user).to eq(existing_user)
      expect(order.email).to eq(existing_user.email)
    end

    it 'associates new user with order using raw ID' do
      put :update, params: { user_id: existing_user.id, order_id: order.to_param }, as: :turbo_stream

      expect(order.reload.user).to eq(existing_user)
      expect(order.email).to eq(existing_user.email)
    end

    it 'sets success flash and redirects to order edit' do
      put :update, params: { user_id: existing_user.to_param, order_id: order.to_param }, as: :turbo_stream

      expect(flash[:success]).to be_present
      expect(response).to redirect_to(spree.edit_admin_order_path(order))
    end

    context 'with an invalid user_id' do
      it 'redirects to orders index' do
        put :update, params: { user_id: 'invalid_prefix_id', order_id: order.to_param }, as: :turbo_stream

        expect(response).to redirect_to(spree.admin_orders_path)
      end
    end
  end

  describe '#destroy' do
    subject { delete :destroy, params: { order_id: order.to_param }, as: :turbo_stream }

    let!(:existing_user) { create(:user, email: user_params[:email]) }

    before { order.associate_user!(existing_user) }

    it 'removes user association from order' do
      subject

      expect(order.reload.user).to be_nil
      expect(order.email).to be_nil
      expect(order.ship_address).to be_nil
      expect(order.bill_address).to be_nil
    end

    it 'redirects to order edit' do
      subject

      expect(response).to redirect_to(spree.edit_admin_order_path(order))
    end

    context 'for an order in payment state' do
      before { order.update(state: 'payment') }

      it 'removes user association but leaves the email address' do
        subject

        expect(order.reload.user).to be_nil
        expect(order.email).to eq(user_params[:email])
        expect(order.ship_address).to be_nil
        expect(order.bill_address).to be_nil
      end
    end
  end

  describe 'order not found' do
    it 'redirects to orders index' do
      put :update, params: { user_id: 'usr_abc123', order_id: 'or_nonexistent' }, as: :turbo_stream

      expect(response).to redirect_to(spree.admin_orders_path)
    end
  end
end
