require 'spec_helper'

describe Spree::PostsController, type: :controller do
  render_views

  let(:store) { @default_store }

  before do
    allow(controller).to receive(:current_store).and_return(store)
  end

  describe '#index' do
    subject { get :index }

    it 'renders the index template' do
      subject
      expect(response).to render_template(:index)
      expect(response).to have_http_status(:ok)
    end

    describe 'pagination' do
      let!(:posts) { create_list(:post, 25, :published, store: store) }

      context 'with Pagy (default)' do
        before { Spree::Storefront::Config[:use_kaminari_pagination] = false }

        it 'paginates posts with Pagy' do
          subject
          expect(assigns(:pagy)).to be_a(Pagy::Offset)
          expect(assigns(:posts).size).to eq(20)
        end

        it 'returns next page' do
          get :index, params: { page: 2 }
          expect(assigns(:pagy).page).to eq(2)
          expect(assigns(:posts).size).to eq(5)
        end
      end

      context 'with Kaminari' do
        before { Spree::Storefront::Config[:use_kaminari_pagination] = true }
        after { Spree::Storefront::Config[:use_kaminari_pagination] = false }

        it 'paginates posts with Kaminari' do
          subject
          expect(assigns(:pagy)).to be_nil
          expect(assigns(:posts)).to respond_to(:total_pages)
          expect(assigns(:posts).size).to eq(20)
        end

        it 'returns next page' do
          get :index, params: { page: 2 }
          expect(assigns(:posts).current_page).to eq(2)
          expect(assigns(:posts).size).to eq(5)
        end
      end
    end
  end
end
