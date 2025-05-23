require 'spec_helper'

RSpec.describe Spree::Admin::PageBlocksController, type: :controller do
  stub_authorization!
  render_views

  let(:page) { create(:page, :preview) }
  let(:theme) { create(:theme, :preview) }

  before do
    page.update!(pageable: theme.parent)

    session[:page_preview_id] = page.id
    session[:theme_preview_id] = theme.id
  end

  describe '#destroy' do
    let(:page_section) { create(:featured_taxon_page_section, pageable: page) }
    let!(:page_block) { create(:page_block, :buttons, section: page_section) }

    it 'destroys the page block' do
      delete :destroy, params: { id: page_block.id, page_section_id: page_section.id }, format: :turbo_stream

      expect(page_block.reload).to be_deleted
    end
  end

  describe '#move_higher' do
    let(:page_section) { create(:featured_taxon_page_section) }
    let!(:another_page_block) { create(:page_block, :buttons, section: page_section, position: 1) }
    let!(:page_block) { create(:page_block, :buttons, section: page_section, position: 2) }

    it 'moves the page block higher' do
      put :move_higher, params: { id: page_block.id, page_section_id: page_section.id }, format: :turbo_stream

      expect(page_block.reload.position).to eq 1
    end
  end

  describe '#move_lower' do
    let(:page_section) { create(:featured_taxon_page_section) }
    let!(:page_block) { create(:page_block, :buttons, section: page_section, position: 1) }
    let!(:another_page_block) { create(:page_block, :buttons, section: page_section, position: 2) }

    it 'moves the page block lower' do
      put :move_lower, params: { id: page_block.id, page_section_id: page_section.id }, format: :turbo_stream

      expect(page_block.reload.position).to eq 2
    end
  end

  describe '#create' do
    subject { post :create, params: { page_block: { type: page_block_type }, page_section_id: page_section.id }, format: :turbo_stream }

    let(:page_block_type) { 'Spree::PageBlocks::Buttons' }
    let(:page_section) { create(:featured_taxon_page_section) }

    it 'creates page block of the given type' do
      expect { subject }.to change(Spree::PageBlock, :count).by(1)
      expect(page_section.page_blocks.last.type).to eq(page_block_type)
    end

    context 'when the type is not allowed' do
      let(:page_block_type) { 'Spree::PageBlocks::Checkboxes' }

      it 'does not create a page block' do
        expect { subject }.not_to change(Spree::PageBlock, :count)
      end
    end
  end

  describe '#edit' do
    subject { get :edit, params: { id: page_block.id, page_section_id: page_section.id } }

    let(:page_block) { create(:page_block, :buttons, section: page_section) }
    let(:page_section) { create(:featured_taxon_page_section) }

    it 'renders the edit template' do
      subject

      expect(response).to render_template(:edit)
    end
  end

  describe '#update' do
    subject { put :update, params: { id: page_block.id, page_section_id: page_section.id, page_block: page_block_params }, format: :turbo_stream }

    let(:page_block) { create(:buttons_block, section: page_section) }
    let(:page_section) { create(:featured_taxon_page_section) }
    let(:page_block_params) { { preferred_button_text_color: '#000000' } }

    it 'updates the page block' do
      expect { subject }.to change { page_block.reload.preferred_button_text_color }.to('#000000')
    end

    context 'with link' do
      let!(:page_block) { create(:buttons_block, section: page_section) }

      let(:page_block_params) { { link_attributes: { id: page_block.link.id, label: 'New Label', open_in_new_tab: true } } }

      it 'updates the page block' do
        subject

        expect(page_block.reload.link.label).to eq('New Label')
        expect(page_block.reload.link.open_in_new_tab).to be_truthy
      end
    end
  end

  describe '#allowed_types' do
    subject { controller.send(:allowed_types) }

    let(:page_section) { create(:featured_taxon_page_section) }

    before do
      allow(controller).to receive(:parent).and_return(page_section)
    end

    it 'returns the section allowed types' do
      expect(subject).to include(
        Spree::PageBlocks::Buttons,
        Spree::PageBlocks::Image,
        Spree::PageBlocks::Text
      )
    end

    context 'with custom page section class' do
      class CustomPageBlock < Spree::PageBlock
        def self.name
          'Spree::PageBlocks::Custom'
        end
      end

      class CustomPageSection < Spree::PageSections::FeaturedTaxon
        def available_blocks_to_add
          [CustomPageBlock]
        end
      end

      let(:page_section) { CustomPageSection.new }

      it 'returns the section allowed types' do
        expect(subject).to include(CustomPageBlock)
      end
    end
  end
end
