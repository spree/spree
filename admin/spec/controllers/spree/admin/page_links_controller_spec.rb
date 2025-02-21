require 'spec_helper'

RSpec.describe Spree::Admin::PageLinksController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { Spree::Store.default }

  let(:page) { create(:page, :preview) }
  let(:theme) { create(:theme, :preview) }

  before do
    page.update!(pageable: theme.parent)

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
      let(:taxonomy) { store.taxonomies.first }
      let!(:taxon) { create(:taxon, taxonomy: taxonomy, parent: taxonomy.root) }
      let!(:page_section) { create(:featured_taxons_page_section) }

      it 'creates a new page link' do
        expect { post_create }.to change { page_section.links.count }.by 1
        expect(page_section.links.last.linkable).to be_a Spree::Taxon
      end
    end

    context 'for featured taxons' do
      let(:taxonomy) { store.taxonomies.find_by(name: 'Categories') || create(:taxonomy, name: 'Categories') }
      let!(:category) { create(:taxon, taxonomy: taxonomy, parent: taxonomy.root) }
      let!(:page_section) { create(:featured_taxons_page_section) }

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

      let(:page_section) { create(:header_page_section) }
      let(:page_block) { create(:page_block, :nav, section: page_section) }

      it 'creates a new page link' do
        expect { post_create }.to change { page_block.links.count }.by 1
        expect(page_block.links.last.linkable).to be_a Spree::Pages::Homepage
      end
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
