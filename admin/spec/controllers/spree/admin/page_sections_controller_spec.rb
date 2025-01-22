require 'spec_helper'

RSpec.describe Spree::Admin::PageSectionsController, type: :controller do
  stub_authorization!
  render_views

  let(:page) { create(:page, :preview) }
  let(:theme) { create(:theme, :preview) }

  before do
    page.update!(pageable: theme.parent)

    session[:page_preview_id] = page.id
    session[:theme_preview_id] = theme.id
  end

  describe '#create' do
    context 'with page' do
      it 'creates a page section inside the page' do
        create_req = lambda {
          post :create, params: { page_section: { type: 'Spree::PageSections::FeaturedTaxon' }, page_id: page.id }, format: :turbo_stream
        }

        expect(&create_req).to change(page.page_sections, :count).by(1)
        expect(page.page_sections.last.type).to eq 'Spree::PageSections::FeaturedTaxon'
      end
    end

    context 'with theme' do
      it 'creates a page section inside the theme' do
        create_req = lambda {
          post :create, params: { page_section: { type: 'Spree::PageSections::FeaturedTaxon' }, theme_id: theme.id }, format: :turbo_stream
        }

        expect(&create_req).to change(theme.layout_sections, :count).by(1)
        expect(theme.layout_sections.last.type).to eq 'Spree::PageSections::FeaturedTaxon'
      end
    end
  end

  describe '#destroy' do
    context 'when page section can be deleted' do
      let!(:page_section) { create(:featured_taxon, pageable: page) }

      it 'deletes the page section' do
        expect { delete :destroy, params: { id: page_section.id }, format: :turbo_stream }.to change(Spree::PageSection, :count).by(-1)
      end
    end

    context 'when page section cannot be deleted' do
      let!(:page_section) { create(:page_section, :header) }

      it 'does not delete the page section' do
        expect { delete :destroy, params: { id: page_section.id }, format: :turbo_stream }.to change(Spree::PageSection, :count).by(0)
      end
    end
  end

  describe '#move_higher' do
    context 'within page' do
      let!(:another_page_section) { create(:featured_taxon, pageable: page, position: 1) }
      let!(:page_section) { create(:featured_taxon, pageable: page, position: 2) }

      it 'moves the page section higher' do
        put :move_higher, params: { id: page_section.id, page_id: page.id }, format: :turbo_stream

        expect(page_section.reload.position).to eq 1
      end
    end

    context 'within theme' do
      let!(:another_page_section) { create(:featured_taxon, pageable: theme, pageable_type: "Spree::Theme", position: 1) }
      let!(:page_section) { create(:featured_taxon, pageable: theme, pageable_type: "Spree::Theme", position: 2) }

      it 'moves the page section higher' do
        old_position = page_section.position
        put :move_higher, params: { id: page_section.id, theme_id: theme.id }, format: :turbo_stream

        expect(page_section.reload.position).to be < old_position
      end
    end
  end

  describe '#move_lower' do
    context 'within page' do
      let!(:page_section) { create(:featured_taxon, pageable: page, position: 1) }
      let!(:another_page_section) { create(:featured_taxon, pageable: page, position: 2) }

      it 'moves the page section lower' do
        put :move_lower, params: { id: page_section.id, page_id: page.id }, format: :turbo_stream

        expect(page_section.reload.position).to eq 2
      end
    end

    context 'within theme' do
      let!(:page_section) { create(:featured_taxon, pageable: theme, pageable_type: "Spree::Theme", position: 1) }
      let!(:another_page_section) { create(:featured_taxon, pageable: theme, pageable_type: "Spree::Theme", position: 2) }

      it 'moves the page section lower' do
        old_position = page_section.position
        put :move_lower, params: { id: page_section.id, theme_id: theme.id }, format: :turbo_stream

        expect(page_section.reload.position).to be > old_position
      end
    end
  end

  describe '#restore_design_settings_to_defaults' do
    let(:page_section) { create(:featured_taxon, preferred_top_padding: 50) }

    it 'restores the design settings to defaults' do
      expect(page_section.preferred_top_padding).to eq 50

      put :restore_design_settings_to_defaults, params: { id: page_section.id }, format: :turbo_stream

      expect(page_section.reload.preferred_top_padding).to eq 40
    end
  end
end
