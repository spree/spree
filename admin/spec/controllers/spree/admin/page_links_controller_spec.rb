require 'spec_helper'

RSpec.describe Spree::Admin::PageLinksController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { @default_store }
  let(:theme) { create(:theme, :preview, parent: store.default_theme) }
  let(:page) { create(:page, :preview, pageable: store.default_theme) }

  before do
    session[:page_preview_id] = page.id
    session[:theme_preview_id] = theme.id
  end

  describe '#create' do
    subject :post_create do
      post :create, params: { page_section_id: page_section.id }, as: :turbo_stream
    end

    before do
      allow(Spree::Theme).to receive(:find).and_return Spree::Theme.new(parent: Spree::Theme.take)
      allow(Spree::Page).to receive(:find).and_return Spree::Page.new(parent: Spree::Page.take)
    end

    context 'for header' do
      let!(:page_section) { Spree::PageSections::Header.take }

      it 'creates a new page link' do
        expect { post_create }.to change { page_section.links.count }.by 1
        expect(page_section.links.last.linkable).to be_a Spree::Pages::Homepage
      end
    end

    context 'for featured taxons' do
      let!(:taxon) { create(:taxon, taxonomy: store.taxonomies.first) }
      let!(:page_section) { create(:featured_taxons_page_section, pageable: page) }

      it 'creates a new page link' do
        expect { post_create }.to change { page_section.links.count }.by 1
        expect(page_section.links.last.linkable).to be_a Spree::Taxon
      end
    end

    context 'for any other page section' do
      let!(:page_section) { Spree::PageSections::Footer.take }

      it 'creates a new page link' do
        expect { post_create }.to change { page_section.links.count }.by 1
        expect(page_section.links.last.linkable).to be_a Spree::Pages::Homepage
      end
    end

    context 'for nav page block' do
      subject :post_create do
        post :create, params: { page_section_id: page_section.id, block_id: page_block.id }, as: :turbo_stream
      end

      let(:page_section) { create(:header_page_section, pageable: theme) }
      let(:page_block) { create(:page_block, :nav, section: page_section) }

      it 'creates a new page link' do
        expect { post_create }.to change { page_block.links.count }.by 1
        expect(page_block.links.last.linkable).to be_a Spree::Pages::Homepage
      end
    end

    context 'for store checkout' do
      subject :post_create do
        post :create, params: { store_id: store.id }, as: :turbo_stream
      end

      it 'creates a new page link' do
        expect { post_create }.to change { store.page_links.count }.by 1
      end
    end
  end

  describe '#edit' do
    subject :get_edit do
      get :edit, params: { id: page_link.id }
    end

    let(:page_link) { create(:page_link) }

    it 'renders the edit template' do
      get_edit

      expect(response).to render_template(:edit)
    end
  end

  describe '#update' do
    subject :post_update do
      post :update, params: { id: page_link.id, page_link: { label: 'New Label', position: 2 } }, as: :turbo_stream
    end

    let(:page_link) { create(:page_link) }

    it 'updates the page link' do
      expect { post_update }.to change { page_link.reload.label }.to 'New Label'
      expect(page_link.reload.position).to eq(2)
    end

    it 'renders the update template' do
      post_update

      expect(response).to render_template(:update)
    end
  end

  describe '#destroy' do
    let(:page_link) { create(:page_link) }

    it 'destroys the page link' do
      delete :destroy, params: { id: page_link.id }, format: :turbo_stream

      expect(Spree::PageLink.find_by(id: page_link.id)).to be_nil
    end
  end
end
