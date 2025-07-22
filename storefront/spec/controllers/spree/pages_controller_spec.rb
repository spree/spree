require 'spec_helper'

RSpec.describe Spree::PagesController, type: :controller do
  describe 'GET #show' do
    let(:store) { @default_store }
    let(:page) { create(:custom_page, pageable: store) }

    render_views

    before do
      allow(controller).to receive(:current_store).and_return(store)
      get :show, params: { id: page.slug }
    end

    it 'returns http success' do
      expect(response).to have_http_status(:success)
    end

    it 'assigns @page' do
      expect(assigns(:page)).to eq(page)
    end

    it 'assigns @current_page' do
      expect(assigns(:current_page)).to eq(page)
    end

    it 'renders the show template' do
      expect(response).to render_template(:show)
    end

    context 'when page does not exist' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          get :show, params: { id: 'non-existent' }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
