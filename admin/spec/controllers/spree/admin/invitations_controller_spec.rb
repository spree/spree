require 'spec_helper'

RSpec.describe Spree::Admin::InvitationsController, type: :controller do
  render_views

  let(:store) { @default_store }
  let(:admin_user) { create(:admin_user) }
  let(:invitation) { create(:invitation, inviter: admin_user, resource: store) }
  let(:role) { Spree::Role.find_or_create_by!(name: 'admin') }

  before do
    allow(controller).to receive(:spree_admin_login_path).and_return('/admin/login')
    allow(spree).to receive(:root_path).and_return('/')
  end

  describe 'GET #index' do
    stub_authorization!

    before do
      invitation
      get :index
    end

    it 'returns a successful response' do
      expect(response).to be_successful
    end

    it 'assigns @search' do
      expect(assigns(:search)).to be_a(Ransack::Search)
    end

    it 'assigns @collection' do
      expect(assigns(:collection)).to be_a(ActiveRecord::Relation)
      expect(assigns(:collection)).to include(invitation)
    end
  end

  describe 'GET #new' do
    stub_authorization!

    before { get :new }

    it 'returns a successful response' do
      expect(response).to be_successful
    end

    it 'assigns @invitation' do
      expect(assigns(:invitation)).to be_a_new(Spree::Invitation)
    end

    it 'sets the resource and inviter' do
      expect(assigns(:invitation).resource).to eq(store)
      expect(assigns(:invitation).inviter).to eq(controller.try_spree_current_user)
    end
  end

  describe 'POST #create' do
    stub_authorization!

    let(:valid_params) do
      {
        invitation: {
          email: 'new@example.com',
          expires_at: 1.week.from_now,
          role_id: role.id
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a new invitation' do
        expect {
          post :create, params: valid_params
        }.to change(Spree::Invitation, :count).by(1)
      end

      it 'redirects to invitations path' do
        post :create, params: valid_params
        expect(response).to redirect_to(spree.admin_invitations_path)
      end

      it 'sets a flash message' do
        post :create, params: valid_params
        expect(flash[:notice]).not_to be_nil
      end

      context 'when the invitee already exists' do
        let!(:invitee) { create(:admin_user, :without_admin_role, email: valid_params[:invitation][:email]) }

        before do
          post :create, params: valid_params
        end

        it 'sets the invitee' do
          expect(assigns(:invitation).invitee).to eq(invitee)
          expect(assigns(:invitation)).to be_persisted
        end
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          invitation: {
            email: ''
          }
        }
      end

      it 'does not create a new invitation' do
        expect {
          post :create, params: invalid_params
        }.not_to change(Spree::Invitation, :count)
      end

      it 'renders the new template' do
        post :create, params: invalid_params
        expect(response).to render_template(:new)
      end

      it 'returns unprocessable entity status' do
        post :create, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET #show' do
    let(:token) { invitation.token }

    context 'when user is logged in' do
      let(:another_user) { create(:admin_user, :without_admin_role) }

      before do
        allow(controller).to receive(:try_spree_current_user).and_return(another_user)
      end

      context 'when user is the invitee' do
        let(:invitation) { create(:invitation, inviter: admin_user, resource: store, invitee: another_user) }

        before { get :show, params: { id: invitation.id, token: token } }

        it 'returns a successful response' do
          expect(response).to be_successful
        end

        it 'assigns @invitation' do
          expect(assigns(:invitation)).to eq(invitation)
        end

        it 'renders the show template' do
          expect(response).to render_template(:show)
          expect(response.body).to include(invitation.inviter.name)
          expect(response.body).to include(invitation.resource.name)
        end
      end

      context 'when user is not the invitee' do
        let(:invitation) { create(:invitation, inviter: admin_user, resource: store, invitee: nil) }

        before { get :show, params: { id: invitation.id, token: token } }

        it 'redirects to root path' do
          expect(response).to redirect_to(spree.root_path)
        end

        it 'sets an alert flash message' do
          expect(flash[:alert]).to eq(Spree.t('invalid_or_expired_invitation'))
        end
      end
    end

    context 'when user is not logged in' do
      before do
        allow(controller).to receive(:try_spree_current_user).and_return(nil)
        get :show, params: { id: invitation.id, token: token }
      end

      it 'redirects to new admin user path' do
        expect(response).to redirect_to(spree.new_admin_admin_user_path(token: token))
      end

      context 'with invalid token' do
        let(:token) { 'invalid' }

        it 'redirects to root path' do
          expect(response).to redirect_to(spree.root_path)
        end

        it 'sets an alert flash message' do
          expect(flash[:alert]).to eq(Spree.t('invalid_or_expired_invitation'))
        end
      end

      context 'with expired token' do
        let(:invitation) { create(:invitation, inviter: admin_user, resource: store, expires_at: 1.day.ago) }

        it 'redirects to root path' do
          expect(response).to redirect_to(spree.root_path)
          expect(flash[:alert]).to eq(Spree.t('invalid_or_expired_invitation'))
        end
      end

      context 'when invitation has invitee' do
        let(:invitation) { create(:invitation, inviter: admin_user, resource: store, invitee: invitee, email: invitee.email) }
        let(:invitee) { create(:admin_user, :without_admin_role) }

        it 'redirects to login path' do
          expect(response).to redirect_to(controller.spree_admin_login_path)
        end

        it 'stores the return to path' do
          expect(session["#{Spree.admin_user_class.model_name.singular_route_key.to_sym}_return_to"]).to eq(spree.admin_invitation_path(invitation, token: invitation.token))
        end

        context 'with already accepted invitation' do
          let(:invitation) { create(:invitation, inviter: admin_user, resource: store, status: 'accepted', invitee: invitee, email: invitee.email) }

          it 'redirects to root path' do
            expect(response).to redirect_to(spree.root_path)
            expect(flash[:alert]).to eq(Spree.t('invalid_or_expired_invitation'))
          end
        end
      end
    end
  end

  describe 'PUT #accept' do
    let(:invitation) { create(:invitation, inviter: admin_user, invitee: another_user, resource: store) }
    let(:another_user) { create(:user) }

    before do
      allow(controller).to receive(:current_ability).and_return(Spree.ability_class.new(another_user))
      allow(controller).to receive(:try_spree_current_user).and_return(another_user)
      put :accept, params: { id: invitation.id }
    end

    it 'accepts the invitation' do
      expect(invitation.reload.status).to eq('accepted')
      expect(invitation.accepted_at).to be_present
    end

    it 'redirects to admin path' do
      expect(response).to redirect_to(spree.admin_path)
    end

    it 'sets a notice flash message' do
      expect(flash[:notice]).to eq(Spree.t('invitation_accepted'))
    end
  end

  describe 'PUT #resend' do
    stub_authorization!

    before { Spree::Events.activate! }
    after { Spree::Events.reset! }

    it 'publishes invitation.resend event' do
      invitation
      clear_enqueued_jobs
      expect { put :resend, params: { id: invitation.id } }.to have_enqueued_job(Spree::Events::SubscriberJob)
    end

    it 'redirects to invitations path' do
      put :resend, params: { id: invitation.id }
      expect(response).to redirect_to(spree.admin_invitations_path)
      expect(flash[:notice]).to eq(Spree.t('invitation_resent'))
    end
  end

  describe 'DELETE #destroy' do
    stub_authorization!

    it 'destroys the invitation' do
      invitation # ensure invitation exists
      expect {
        delete :destroy, params: { id: invitation.id }
      }.to change(Spree::Invitation, :count).by(-1)
    end

    it 'redirects to invitations path' do
      delete :destroy, params: { id: invitation.id }
      expect(response).to redirect_to(spree.admin_invitations_path)
    end

    it 'sets a notice flash message' do
      delete :destroy, params: { id: invitation.id }
      expect(flash[:notice]).not_to be_nil
    end
  end
end
