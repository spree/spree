require 'spec_helper'

RSpec.describe Spree::ThemeHelper, type: :helper do
  let(:store) { @default_store }
  let(:theme) { store.default_theme }
  let(:page) { theme.pages.find_by(type: 'Spree::Pages::Homepage') }
  let(:section) { page.sections.first }
  let(:theme_preview) { theme.create_preview }
  let(:page_preview) { page.create_preview }
  let(:block) { create(:heading_block, section: section, preferred_text_alignment: 'center', preferred_width_desktop: 100, preferred_top_padding: 10, preferred_bottom_padding: 10, preferred_background_color: '#ffffff') }

  before do
    allow(helper).to receive(:current_store).and_return(store)
    allow(helper).to receive(:params).and_return({})
  end

  describe '#current_page' do
    it 'returns the current homepage' do
      expect(helper.current_page).to eq(page)
    end
  end

  describe '#current_theme' do
    it 'returns the current theme' do
      expect(helper.current_theme).to eq(theme)
    end
  end

  describe '#current_theme_preview' do
    it 'returns the current theme preview' do
      allow(helper).to receive(:params).and_return(theme_id: theme.id, theme_preview_id: theme_preview.id)
      expect(helper.current_theme_preview).to eq(theme_preview)
    end
  end

  describe '#current_page_preview' do
    it 'returns the current page preview' do
      allow(helper).to receive(:params).and_return(page_id: page.id, page_preview_id: page_preview.id)
      expect(helper.current_page_preview).to eq(page_preview)
    end
  end

  describe '#current_page_or_preview' do
    it 'returns the current page if no preview is present' do
      expect(helper.current_page_or_preview).to eq(page)
    end

    it 'returns the current page preview if present' do
      allow(helper).to receive(:params).and_return(page_id: page.id, page_preview_id: page_preview.id)
      expect(helper.current_page_or_preview).to eq(page_preview)
    end
  end

  describe '#current_theme_or_preview' do
    it 'returns the current theme if no preview is present' do
      expect(helper.current_theme_or_preview).to eq(theme)
    end

    it 'returns the current theme preview if present' do
      allow(helper).to receive(:params).and_return(theme_id: theme.id, theme_preview_id: theme_preview.id)
      expect(helper.current_theme_or_preview).to eq(theme_preview)
    end
  end

  describe '#current_header_logo' do
    let!(:header_section) { theme.sections.find_by(type: 'Spree::PageSections::Header') }

    before do
      header_section.logo.attach(io: File.new(Spree::Core::Engine.root + 'spec/fixtures/thinking-cat.jpg'), filename: 'thinking-cat.jpg')
    end

    it 'returns the logo of the header section' do
      expect(helper.current_header_logo).to be_present
      expect(helper.current_header_logo).to be_attached
      expect(helper.current_header_logo.filename.to_s).to eq('thinking-cat.jpg')
    end
  end

  describe '#page_builder_enabled?' do
    it 'returns true if page builder is enabled' do
      allow(helper).to receive(:params).and_return(theme_preview_id: theme_preview.id, page_builder: 'true')
      expect(helper.page_builder_enabled?).to be_truthy
    end

    it 'returns false if page builder is not enabled' do
      expect(helper.page_builder_enabled?).to be_falsey
    end
  end

  describe '#theme_layout_sections' do
    it 'returns a hash of sections by type' do
      sections = { 'header' => section }
      allow(helper).to receive(:current_theme_or_preview).and_return(theme)
      allow(theme).to receive_message_chain(:sections, :includes, :all, :each_with_object).and_return(sections)
      expect(helper.theme_layout_sections).to eq(sections)
    end
  end

  describe '#theme_setting' do
    it 'returns the theme setting value' do
      allow(theme).to receive_message_chain(:preferences, :with_indifferent_access).and_return('background_color' => '#ffffff')
      expect(helper.theme_setting('background_color')).to eq('#ffffff')
    end
  end

  describe '#theme_setting_rgb_components' do
    it 'returns the RGB components of the theme setting' do
      allow(helper).to receive(:theme_setting).with('background_color').and_return('#ffffff')
      expect(helper.theme_setting_rgb_components('background_color')).to eq('255, 255, 255')
    end
  end

  describe '#hex_color_to_rgb' do
    it 'converts hex color to RGB' do
      expect(helper.hex_color_to_rgb('#ffffff')).to eq('rgb(255, 255, 255)')
    end
  end

  describe '#hex_color_to_rgba' do
    it 'converts hex color to RGBA' do
      expect(helper.hex_color_to_rgba('#ffffff')).to eq('rgba(255, 255, 255, 1.0)')
    end
  end

  # TODO: Fix this test
  xdescribe '#section_styles' do
    it 'returns the styles for a section' do
      styles = "background-color: #ffffff;--section-background: #ffffff;color: #000000;--section-color: #000000;"
      expect(helper.section_styles(section)).to include(styles)
    end
  end

  describe '#section_heading_styles' do
    it 'returns the styles for a section heading' do
      allow(helper).to receive(:theme_setting).with('headings_uppercase').and_return(true)
      styles = "text-transform: uppercase"
      expect(helper.section_heading_styles(section)).to eq(styles)
    end
  end

  describe '#block_attributes' do
    it 'returns the attributes for a block' do
      expect(helper.block_attributes(block)).to include("data-editor-id=\"block-#{block.id}\"")
      expect(helper.block_attributes(block)).to include("data-editor-name=\"#{block.display_name}\"")
      expect(helper.block_attributes(block)).to include("data-editor-parent-id=\"section-#{block.section_id}\"")
      expect(helper.block_attributes(block)).to include("id=\"block-#{block.id}\"")
      expect(helper.block_attributes(block)).to include("class=\"block-heading\"")
    end
  end

  # TODO: Fix this test
  xdescribe '#link_attributes' do
    it 'returns the attributes for a link' do
      link = create(:page_link, parent: section)
      attributes = {
        data: {
          editor_id: "link-#{link.id}",
          editor_name: link.label,
          editor_parent_id: "section-#{link.parent_id}",
          editor_link: nil
        },
        id: "link-#{link.id}",
        class: "link-#{link.class.name.demodulize.underscore.dasherize}"
      }
      expect(helper.link_attributes(link, as_html: false)).to eq(attributes)
    end
  end

  describe '#block_styles' do
    it 'returns the styles for a block' do
      styles = "text-align: center;width: 100%;margin: 0 auto 0 0;color: var(--section-color);padding-top: 10px;padding-bottom: 10px;background-color: #ffffff"
      expect(helper.block_styles(block)).to eq(styles)
    end
  end

  describe '#block_background_color_style' do
    it 'returns the background color style for a block' do
      allow(block).to receive(:preferred_background_color).and_return('#ffffff')
      expect(helper.block_background_color_style(block)).to eq('background-color: #ffffff;')
    end
  end

  describe '#block_css_classes' do
    it 'returns the CSS classes for a block' do
      allow(block).to receive(:preferred_justify).and_return('center')
      expect(helper.block_css_classes(block)).to eq('justify-center')
    end
  end
end
