require 'spec_helper'

RSpec.describe Spree::PageSectionsController, type: :controller do
  let(:store) { Spree::Store.default }
  let(:theme) { create(:theme, store: store) }
  let(:section) { create(:featured_taxon_page_section) }

  before do
    allow(controller).to receive(:current_store).and_return(store)
    allow(controller).to receive(:current_theme).and_return(theme)
  end

  describe 'GET #show' do
    context 'when section exists' do
      before { get :show, params: { id: section.id } }

      it 'assigns @section' do
        expect(assigns(:section)).to eq(section)
      end

      it 'renders the show template' do
        expect(response).to render_template(:show)
      end
    end

    context 'when section does not exist' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          get :show, params: { id: 'nonexistent' }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
