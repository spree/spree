require 'spec_helper'

RSpec.describe Spree::Themes::DuplicateComponentsJob do
  subject { described_class.perform_now(theme.id, duplicated_theme.id) }

  let(:ignored_file_attrs) { %w[id created_at updated_at theme_id preferences] }

  let!(:theme) { create(:theme, :blank, name: 'Marketplace Theme', default: true) }
  let!(:duplicated_theme) { create(:theme, name: 'Copy #1 of Marketplace Theme', duplicating: true, default: false, ready: false) }

  let!(:theme_section_1) do
    create(
      :announcement_bar_page_section,
      pageable: theme,
      pageable_type: 'Spree::Theme',
      preferences: {
        background_color: '#FF0000',
        text_color: '#FFFFFF',
        border_color: '#000000',
        top_padding: 20,
        bottom_padding: 20,
        top_border_width: 2,
        bottom_border_width: 4,
        enabled: true
      }
    )
  end

  let!(:theme_section_2) do
    create(
      :header_page_section,
      :without_links,
      pageable: theme,
      pageable_type: 'Spree::Theme',
      preferences: {
        background_color: '#FF0000',
        text_color: '#FFFFFF',
        border_color: '#000000',
        layout: 'default',
        desktop_logo_height: 100,
        border_width: 1,
        top_padding: 15,
        bottom_padding: 15,
        top_border_width: 3,
        bottom_border_width: 3
      }
    )
  end

  let!(:theme_file_2_section_links) do
    [
      create(:page_link, parent: theme_section_2, linkable: page_2)
    ]
  end

  let!(:page_1) { create(:page, :homepage, pageable: theme) }
  let!(:page_1_section) { create(:rich_text_page_section, pageable: page_1) }
  let!(:page_1_section_block) { create(:page_block, :heading, section: page_1_section) }
  let!(:page_1_section_block_link) { create(:page_link, parent: page_1_section_block, linkable: page_2) }

  let!(:page_2) { create(:page, :account, pageable: theme) }
  let!(:page_2_section) { create(:header_page_section, :without_links, pageable: page_2) }
  let!(:page_2_section_links) do
    [
      create(:page_link, parent: page_2_section, linkable: page_1, label: 'Homepage'),
      create(:page_link, parent: page_2_section, linkable: custom_page, label: 'Custom page')
    ]
  end

  let(:duplicated_section_1) { duplicated_theme.sections.find_by(name: theme_file_1_section.name) }
  let(:duplicated_section_2) { duplicated_theme.sections.find_by(name: theme_file_2_section.name) }

  let(:duplicated_page_1) { duplicated_theme.pages.find_by(type: page_1.type) }
  let(:duplicated_page_1_section) { duplicated_page_1.sections[0] }
  let(:duplicated_page_1_section_block) { duplicated_page_1_section.blocks.last }

  let(:duplicated_page_2) { duplicated_theme.pages.find_by(type: page_2.type) }
  let(:duplicated_page_2_section) { duplicated_page_2.sections.find_by!(name: 'Header') }
  let!(:custom_page) { create(:custom_page) }

  it 'duplicates sections and page links' do
    subject

    duplicated_theme_section_1 = duplicated_theme.sections.find_by(name: theme_section_1.name)
    duplicated_theme_section_2 = duplicated_theme.sections.find_by(name: theme_section_2.name)

    expect(duplicated_theme_section_1.pageable).to eq(duplicated_theme)
    expect(duplicated_theme_section_1.preferences).to eq(theme_section_1.preferences)
    expect(duplicated_theme_section_1.links).to be_empty

    expect(duplicated_theme_section_2.pageable).to eq(duplicated_theme)
    expect(duplicated_theme_section_2.preferences).to eq(theme_section_2.preferences)

    expect(duplicated_theme_section_2.links.count).to eq(1)
    expect(duplicated_theme_section_2.links.find_by!(label: 'Account').linkable).to eq(duplicated_page_2)
  end

  it 'duplicates the pages with sections and page links' do
    subject

    expect(duplicated_page_1.name).to eq('Homepage')
    expect(duplicated_page_1_section).to be_present
    expect(duplicated_page_1_section.type).to eq('Spree::PageSections::RichText')
    expect(duplicated_page_1_section_block).to be_present
    expect(duplicated_page_1_section_block.type).to eq('Spree::PageBlocks::Heading')
    expect(duplicated_page_1_section_block.links.count).to eq(1)
    expect(duplicated_page_1_section_block.links[0].label).to eq('Account')
    expect(duplicated_page_1_section_block.links[0].linkable).to eq(duplicated_page_2)

    expect(duplicated_page_2.name).to eq('Account')
    expect(duplicated_page_2_section).to be_present
    expect(duplicated_page_2_section.type).to eq('Spree::PageSections::Header')
    expect(duplicated_page_2_section.links.count).to eq(2)
    expect(duplicated_page_2_section.links.find_by!(label: 'Homepage').linkable).to eq(duplicated_page_1)
    expect(duplicated_page_2_section.links.find_by!(label: 'Custom page').linkable).to eq(custom_page)
  end
end
