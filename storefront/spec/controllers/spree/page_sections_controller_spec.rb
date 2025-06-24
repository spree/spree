require 'spec_helper'

RSpec.describe Spree::PageSectionsController, type: :controller do
  let(:store) { @default_store }
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

      context 'when section is a featured posts section' do
        render_views

        let(:section) { create(:featured_posts_page_section, preferred_max_posts_to_show: 2) }
        let!(:posts) { create_list(:post, 3, published_at: Time.current) }

        it 'renders the show template' do
          expect(response).to render_template(:show)
        end
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
