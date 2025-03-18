require 'spec_helper'

RSpec.describe Spree::SearchController, type: :controller do
  let(:store) { @default_store }
  let(:theme) { create(:theme, store: store) }
  let!(:search_page) { create(:page, type: 'Spree::Pages::SearchResults') }
  let(:query) { 'test query' }

  render_views

  before do
    allow(controller).to receive(:current_store).and_return(store)
    allow(controller).to receive(:current_theme).and_return(theme)
    allow(theme.pages).to receive(:find_by).with(type: 'Spree::Pages::SearchResults').and_return(search_page)
  end

  describe 'GET #show' do
    before { get :show, params: { q: query } }

    it 'assigns @current_page' do
      expect(assigns(:current_page)).to eq(search_page)
    end

    it 'renders the show template' do
      expect(response).to render_template(:show)
    end

    context 'when tracking search' do
      context 'with turbo frame request' do
        before do
          allow(controller).to receive(:turbo_frame_request?).and_return(true)
          get :show, params: { q: query }
        end

        it 'does not track the event' do
          expect(controller).not_to receive(:track_event)
        end
      end

      context 'with blank query' do
        before { get :show, params: { q: '' } }

        it 'does not track the event' do
          expect(controller).not_to receive(:track_event)
        end
      end
    end
  end

  describe 'GET #suggestions' do
    context 'with valid query length' do
      let!(:product) { create(:product_in_stock, stores: [store], name: 'Shirt') }
      let!(:product_2) { create(:product_in_stock, stores: [store], name: 'Shoes') }
      let!(:product_3) { create(:product_in_stock, stores: [store], name: 'Hat') }
      let(:taxonomy) { create(:taxonomy, store: store, name: 'Clothing') }
      let!(:taxon) { create(:taxon, name: 'Shirt', taxonomy: taxonomy) }
      let!(:taxon_2) { create(:taxon, name: 'Shoes', taxonomy: taxonomy) }
      let!(:taxon_3) { create(:taxon, name: 'Hat', taxonomy: taxonomy) }

      let(:query) { 'sh' }

      before do
        get :suggestions, params: { q: query }, format: :turbo_stream
      end

      it 'assigns products array' do
        expect(assigns(:products)).to match_array([product, product_2])
      end

      it 'assigns taxons array' do
        expect(assigns(:taxons)).to match_array([taxon, taxon_2])
      end
    end

    context 'with invalid query length' do
      before do
        allow(Spree::Storefront::Config).to receive(:search_min_query_length).and_return(5)
        get :suggestions, params: { q: 'ab' }, format: :turbo_stream
      end

      it 'assigns empty products array' do
        expect(assigns(:products)).to be_empty
      end

      it 'assigns empty taxons array' do
        expect(assigns(:taxons)).to be_empty
      end
    end

    context 'with blank query' do
      before { get :suggestions, params: { q: ' ' }, format: :turbo_stream }

      it 'assigns empty products array' do
        expect(assigns(:products)).to be_empty
      end

      it 'assigns empty taxons array' do
        expect(assigns(:taxons)).to be_empty
      end
    end
  end

  describe '#query' do
    it 'strips HTML tags and whitespace' do
      controller.params[:q] = " <script>alert('test')</script> query "
      expect(controller.send(:query)).to eq("alert('test') query")
    end

    it 'returns nil for blank query' do
      controller.params[:q] = ''
      expect(controller.send(:query)).to be_nil
    end
  end

  describe '#default_products_sort' do
    it 'returns manual as default sort' do
      expect(controller.send(:default_products_sort)).to eq('manual')
    end
  end
end
