require 'spec_helper'

describe Spree::Account::StoreCreditsController, type: :controller do
  let(:store) { @default_store }
  let(:user) { create(:user) }
  let(:store_credit) { create(:store_credit, user: user) }
  let!(:store_credit_event) { store_credit.store_credit_events.first }

  render_views

  before do
    allow(controller).to receive(:current_store).and_return(store)
    allow(controller).to receive(:spree_login_path).and_return('/login')
  end

  describe '#index' do
    subject { get :index }

    context 'when user is logged in' do
      before do
        allow(controller).to receive_messages try_spree_current_user: user
        allow(controller).to receive_messages spree_current_user: user
      end

      it 'lists store credit events for the user' do
        subject
        expect(assigns(:store_credit_events)).to include(store_credit_event)
        expect(response).to have_http_status(:ok)
      end

      it 'renders the index template' do
        subject
        expect(response).to render_template(:index)
      end

      describe 'pagination' do
        # Each store credit creates 1 event, we need 30 total for 2 pages (25 per page)
        before do
          29.times { create(:store_credit, user: user) }
        end

        context 'with Pagy (default)' do
          before { Spree::Storefront::Config[:use_kaminari_pagination] = false }

          it 'paginates store credit events with Pagy' do
            subject
            expect(assigns(:pagy)).to be_a(Pagy::Offset)
            expect(assigns(:store_credit_events).size).to eq(25)
          end

          it 'returns next page' do
            get :index, params: { page: 2 }
            expect(assigns(:pagy).page).to eq(2)
            expect(assigns(:store_credit_events).size).to eq(5)
          end
        end

        context 'with Kaminari' do
          before { Spree::Storefront::Config[:use_kaminari_pagination] = true }
          after { Spree::Storefront::Config[:use_kaminari_pagination] = false }

          it 'paginates store credit events with Kaminari' do
            subject
            expect(assigns(:pagy)).to be_nil
            expect(assigns(:store_credit_events)).to respond_to(:total_pages)
            expect(assigns(:store_credit_events).size).to eq(25)
          end

          it 'returns next page' do
            get :index, params: { page: 2 }
            expect(assigns(:store_credit_events).current_page).to eq(2)
            expect(assigns(:store_credit_events).size).to eq(5)
          end
        end
      end
    end

    context 'when user is not logged in' do
      it 'redirects to login page' do
        expect(subject).to have_http_status(302)
      end
    end
  end
end
