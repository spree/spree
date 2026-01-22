require 'spec_helper'

RSpec.describe 'Spree environment accessors' do
  describe 'Spree.page_builder' do
    it 'provides access to page builder configuration' do
      expect(Spree.page_builder).to be_a(Spree::PageBuilderConfig)
    end

    it 'memoizes the page_builder instance' do
      expect(Spree.page_builder).to be(Spree.page_builder)
    end

    describe 'getter methods' do
      it 'provides access to themes' do
        expect(Spree.page_builder.themes).to eq(Rails.application.config.spree.themes)
        expect(Spree.page_builder.themes).to be_an(Array)
      end

      it 'provides access to theme_layout_sections' do
        expect(Spree.page_builder.theme_layout_sections).to eq(Rails.application.config.spree.theme_layout_sections)
        expect(Spree.page_builder.theme_layout_sections).to be_an(Array)
      end

      it 'provides access to pages' do
        expect(Spree.page_builder.pages).to eq(Rails.application.config.spree.pages)
        expect(Spree.page_builder.pages).to be_an(Array)
      end

      it 'provides access to page_sections' do
        expect(Spree.page_builder.page_sections).to eq(Rails.application.config.spree.page_sections)
        expect(Spree.page_builder.page_sections).to be_an(Array)
      end

      it 'provides access to page_blocks' do
        expect(Spree.page_builder.page_blocks).to eq(Rails.application.config.spree.page_blocks)
        expect(Spree.page_builder.page_blocks).to be_an(Array)
      end
    end

    describe 'setter methods' do
      it 'allows setting themes' do
        original = Spree.page_builder.themes.dup
        Spree.page_builder.themes = ['Custom::Theme']
        expect(Spree.page_builder.themes).to eq(['Custom::Theme'])
        expect(Rails.application.config.spree.themes).to eq(['Custom::Theme'])
        # Restore original
        Spree.page_builder.themes = original
      end

      it 'allows setting pages' do
        original = Spree.page_builder.pages.dup
        Spree.page_builder.pages = ['Custom::Page']
        expect(Spree.page_builder.pages).to eq(['Custom::Page'])
        expect(Rails.application.config.spree.pages).to eq(['Custom::Page'])
        # Restore original
        Spree.page_builder.pages = original
      end

      it 'allows setting page_sections' do
        original = Spree.page_builder.page_sections.dup
        Spree.page_builder.page_sections = ['Custom::Section']
        expect(Spree.page_builder.page_sections).to eq(['Custom::Section'])
        expect(Rails.application.config.spree.page_sections).to eq(['Custom::Section'])
        # Restore original
        Spree.page_builder.page_sections = original
      end
    end

    describe 'modifying values' do
      it 'allows appending to themes' do
        original = Spree.page_builder.themes.dup
        Spree.page_builder.themes << 'Custom::NewTheme'
        expect(Spree.page_builder.themes).to include('Custom::NewTheme')
        # Restore original
        Spree.page_builder.themes.clear
        Spree.page_builder.themes.concat(original)
      end
    end
  end
end
