require 'spec_helper'

RSpec.describe Spree::Admin::PageSectionsController, type: :controller do
  stub_authorization!
  render_views

  let!(:store) { Spree::Store.default }
  let!(:parent_theme) { create(:theme, store: store) }
  let!(:theme) { create(:theme, :preview, parent: parent_theme) }
  let!(:page) { create(:page, :preview, pageable: parent_theme) }

  before do
    session[:page_preview_id] = page.id
    session[:theme_preview_id] = theme.id

    allow(controller).to receive(:current_store).and_return(store)
  end

  after do
    session.delete(:page_preview_id)
    session.delete(:theme_preview_id)
  end

  describe '#new' do
    it 'renders the new template' do
      get :new, params: { page_id: page.id }
      expect(response).to render_template(:new)
    end
  end

  describe '#create' do
    subject { post :create, params: params, format: :turbo_stream }

    context 'with page' do
      let(:params) { { page_section: { type: page_section_type }, page_id: page.id } }
      let(:page_section_type) { 'Spree::PageSections::FeaturedTaxon' }

      it 'creates a page section inside the page' do
        expect { subject }.to change(page.page_sections, :count).by(1)
        expect(page.page_sections.last.type).to eq(page_section_type)
      end

      context 'when the type is not allowed' do
        let(:page_section_type) { 'Spree::PageSections::Checkboxes' }

        it 'does not create a page section' do
          expect { subject }.not_to change(page.page_sections, :count)
        end
      end
    end

    context 'with theme' do
      let(:params) { { page_section: { type: page_section_type }, theme_id: theme.id } }
      let(:page_section_type) { 'Spree::PageSections::FeaturedTaxon' }

      it 'creates a page section inside the theme' do
        expect { subject }.to change(theme.layout_sections, :count).by(1)
        expect(theme.layout_sections.last.type).to eq(page_section_type)
      end

      context 'when the type is not allowed' do
        let(:page_section_type) { 'Spree::PageSections::Checkboxes' }

        it 'does not create a page section' do
          expect { subject }.not_to change(theme.layout_sections, :count)
        end
      end
    end
  end

  describe '#update' do
    let!(:page_section) { create(:featured_taxon_page_section, pageable: page) }

    it 'updates the page section' do
      put :update, params: { id: page_section.id, page_section: { preferred_top_padding: 100 } }, format: :turbo_stream

      expect(page_section.reload.preferred_top_padding).to eq(100)
    end

    it 'can attach an asset' do
      put :update, params: { id: page_section.id, page_section: { asset: fixture_file_upload('logo.png', 'image/png') } }, format: :turbo_stream

      expect(page_section.reload.asset).to be_attached
    end

    context "with action text field" do
      let!(:page_section) { create(:announcement_bar_page_section, pageable: theme) }

      it "persists page section action text" do
        put :update, params: { id: page_section.id, page_section: { text: "Welcome to our amazing store" } }, format: :turbo_stream

        expect(page_section.reload.text.to_plain_text).to eq("Welcome to our amazing store")
      end
    end

    context "changing position" do
      let(:page_section) { create(:featured_taxon_page_section, pageable: page, position: 1) }

      it "updates the position" do
        put :update, params: { id: page_section.id, page_section: { position: 2 } }, format: :turbo_stream

        expect(page_section.reload.position).to eq(2)
      end
    end

    context 'with link' do
      let(:page_section) { create(:image_with_text_page_section, pageable: page) }

      it 'updates the page section link' do
        put :update, params: { id: page_section.id, page_section: { link_attributes: { id: page_section.link.id, label: 'New Label', open_in_new_tab: true } } }, format: :turbo_stream

        expect(page_section.reload.link.label).to eq('New Label')
        expect(page_section.reload.link.open_in_new_tab).to be_truthy
      end
    end
  end

  describe '#destroy' do
    context 'when page section can be deleted' do
      let!(:page_section) { create(:featured_taxon_page_section, pageable: page) }

      it 'deletes the page section' do
        expect { delete :destroy, params: { id: page_section.id }, format: :turbo_stream }.to change(Spree::PageSection, :count).by(-1)
      end
    end

    context 'when page section cannot be deleted' do
      let!(:page_section) { create(:header_page_section) }

      it 'does not delete the page section' do
        expect { delete :destroy, params: { id: page_section.id }, format: :turbo_stream }.not_to change(Spree::PageSection, :count)
      end
    end
  end

  describe '#move_higher' do
    context 'within page' do
      let!(:another_page_section) { create(:featured_taxon_page_section, pageable: page, position: 1) }
      let!(:page_section) { create(:featured_taxon_page_section, pageable: page, position: 2) }

      it 'moves the page section higher' do
        put :move_higher, params: { id: page_section.id, page_id: page.id }, format: :turbo_stream

        expect(page_section.reload.position).to eq 1
      end
    end

    context 'within theme' do
      let!(:another_page_section) { create(:featured_taxon_page_section, pageable: theme, pageable_type: 'Spree::Theme', position: 1) }
      let!(:page_section) { create(:featured_taxon_page_section, pageable: theme, pageable_type: 'Spree::Theme', position: 2) }

      it 'moves the page section higher' do
        old_position = page_section.position
        put :move_higher, params: { id: page_section.id, theme_id: theme.id }, format: :turbo_stream

        expect(page_section.reload.position).to be < old_position
      end
    end
  end

  describe '#move_lower' do
    context 'within page' do
      let!(:page_section) { create(:featured_taxon_page_section, pageable: page, position: 1) }
      let!(:another_page_section) { create(:featured_taxon_page_section, pageable: page, position: 2) }

      it 'moves the page section lower' do
        put :move_lower, params: { id: page_section.id, page_id: page.id }, format: :turbo_stream

        expect(page_section.reload.position).to eq 2
      end
    end

    context 'within theme' do
      let!(:page_section) { create(:featured_taxon_page_section, pageable: theme, pageable_type: 'Spree::Theme', position: 1) }
      let!(:another_page_section) { create(:featured_taxon_page_section, pageable: theme, pageable_type: 'Spree::Theme', position: 2) }

      it 'moves the page section lower' do
        old_position = page_section.position
        put :move_lower, params: { id: page_section.id, theme_id: theme.id }, format: :turbo_stream

        expect(page_section.reload.position).to be > old_position
      end
    end
  end

  describe '#restore_design_settings_to_defaults' do
    let(:page_section) { create(:featured_taxon_page_section, preferred_top_padding: 50) }

    it 'restores the design settings to defaults' do
      expect(page_section.preferred_top_padding).to eq 50

      put :restore_design_settings_to_defaults, params: { id: page_section.id }, format: :turbo_stream

      expect(page_section.reload.preferred_top_padding).to eq 40
    end
  end
end
