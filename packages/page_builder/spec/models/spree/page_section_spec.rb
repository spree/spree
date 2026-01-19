require 'spec_helper'

RSpec.describe Spree::PageSection, type: :model do
  let(:homepage) { Spree::Page.find_by!(name: 'Homepage') }

  describe 'position' do
    it 'assigns position number in scope of non-deleted page sections' do
      expect(homepage.sections.pluck(:position)).to match_array([1, 2, 3, 4])
      homepage.sections.delete_all
      expect(homepage.sections).to be_blank
      expect(homepage.sections.with_deleted).to be_present

      create_list(:featured_taxon_page_section, 4, pageable: homepage)
      expect(homepage.reload.sections.pluck(:position)).to match_array([1, 2, 3, 4])
    end
  end

  describe '#deep_clone' do
    let(:theme) { create(:theme) }

    shared_examples 'deep clone' do
      it 'creates a deep clone of the page section' do
        expect {
          section.deep_clone(new_preview)
        }.to change { Spree::PageSection.count }.by(1)
          .and change { Spree::PageBlock.count }.by(page_blocks_count)
          .and change { Spree::PageLink.count }.by(page_links_count)


        new_section = Spree::PageSection.last

        expect(new_section.preferences).to eq(section.preferences)
        expect(new_section.preferences).to eq(section.preferences)
        expect(new_section.position).to eq(section.position)
        expect(new_section.pageable).to eq(new_preview)

        expect(new_section.blocks.count).to eq(section.blocks.count)
        expect(new_section.links.count).to eq(section.links.count)

        new_section.blocks.order(position: :asc).each do |block|
          old_block = section.blocks.find_by(position: block.position)

          expect(block.name).to eq(old_block.name)
          expect(block.preferences).to eq(old_block.preferences)
          expect(block.preferences).to eq(old_block.preferences)
          expect(block.link.linkable).to eq(old_block.link.linkable) if old_block.respond_to?(:link)
          expect(block.asset.attachment).to eq(old_block.asset.attachment)

          next unless block.respond_to?(:links)

          expect(block.links.count).to eq(old_block.links.count)
          expect(block.page_links_count).to eq(old_block.page_links_count)

          block.links.each do |link|
            old_link = old_block.links.find_by(position: link.position)

            expect(link.label).to eq(old_link.label)
            expect(link.linkable).to eq(old_link.linkable)
            expect(link.position).to eq(old_link.position)
          end
        end

        new_section.links.each do |link|
          expect(link.linkable).to eq(new_section.links.find_by(label: link.label).linkable)
        end
      end
    end

    context 'for page preview' do
      let(:page) { theme.pages.find_by(type: 'Spree::Pages::Homepage') }
      let!(:new_preview) { page.create_preview }
      let!(:section) { Spree::PageSections::ImageWithText.create!(pageable: page) }

      let(:page_blocks_count) { 3 }
      let(:page_links_count) { 2 }

      it_behaves_like 'deep clone'
    end

    context 'for theme preview' do
      let!(:new_preview) { theme.create_preview }
      let!(:section) { Spree::PageSections::Footer.create!(pageable: theme) }

      let(:page_blocks_count) { 4 }
      let(:page_links_count) { 7 }

      it_behaves_like 'deep clone'
    end

    context 'newsletter section' do
      let!(:new_preview) { theme.create_preview }
      let!(:section) { theme.sections.find_by!(name: "Newsletter") }

      let(:page_blocks_count) { 4 }
      let(:page_links_count) { 0 }

      before do
        Spree::PageBlocks::Image.create!(section: section)
      end

      it_behaves_like 'deep clone'
    end
  end

  describe 'validations' do
    describe 'asset' do
      let(:page_section) { create(:header_page_section) }

      it 'validates content type' do
        page_section.asset.attach(
          io: File.open(Spree::Core::Engine.root.join('spec/fixtures/files/icon_256x256.png')), filename: 'icon_256x256.png',
          content_type: 'image/png'
        )
        expect(page_section).to be_valid

        page_section.asset.attach(
          io: File.open(Spree::Core::Engine.root.join('spec/fixtures/files/example.json')), filename: 'example.json',
          content_type: 'application/json'
        )
        expect(page_section).not_to be_valid
      end
    end
  end

  describe '#restore_design_settings_to_defaults' do
    let(:page_section) do
      create(
        :header_page_section,
        preferences: { text_color: '#000000', background_color: '#FFFFFF', border_color: '#000000', top_padding: 100, bottom_padding: 100, top_border_width: 10, bottom_border_width: 10 }
      )
    end

    it 'restores design settings to defaults' do
      page_section.restore_design_settings_to_defaults

      expect(page_section.preferred_text_color).to eq Spree::PageSections::Header::TEXT_COLOR_DEFAULT
      expect(page_section.preferred_background_color).to eq Spree::PageSections::Header::BACKGROUND_COLOR_DEFAULT
      expect(page_section.preferred_border_color).to eq Spree::PageSections::Header::BORDER_COLOR_DEFAULT
      expect(page_section.preferred_top_padding).to eq Spree::PageSections::Header::TOP_PADDING_DEFAULT
      expect(page_section.preferred_bottom_padding).to eq Spree::PageSections::Header::BOTTOM_PADDING_DEFAULT
      expect(page_section.preferred_top_border_width).to eq Spree::PageSections::Header::TOP_BORDER_WIDTH_DEFAULT
      expect(page_section.preferred_bottom_border_width).to eq Spree::PageSections::Header::BOTTOM_BORDER_WIDTH_DEFAULT
    end
  end
end
