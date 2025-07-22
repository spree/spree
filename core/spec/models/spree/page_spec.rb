require 'spec_helper'

describe Spree::Page, type: :model do
  let(:store) { @default_store }
  let(:theme) { store.default_theme }
  let(:page) { theme.pages.first }

  describe 'validations' do
    describe 'slug' do
      it 'validates uniqueness' do
        other_page = create(:page, slug: 'test-slug')

        page.slug = other_page.slug
        expect(page).not_to be_valid
        expect(page.errors.full_messages).to include('Slug has already been taken')

        other_page.destroy
      end
    end
  end

  context 'slugs' do
    let(:custom_page) { create(:page, pageable: theme, type: 'Spree::Pages::Custom', name: 'Landing Page') }

    it 'should only generate slugs for custom pages' do
      expect(page.slug).to be_nil

      expect(custom_page.slug).not_to be_nil
      expect(custom_page.slug).to eq('landing-page')
    end
  end

  describe '#create_preview' do
    it 'should create a preview' do
      expect { page.create_preview }.to change { page.previews.count }.by(1)

      new_preview = page.previews.last
      expect(new_preview.parent).to eq(page)

      expect(new_preview.sections.count).to eq(page.sections.count)
      expect(new_preview.sections.map(&:display_name)).to contain_exactly(*page.sections.map(&:display_name))
    end
  end

  describe '#promote' do
    let!(:page_preview) { page.create_preview }

    it 'should promote the preview to the main page' do
      expect { page_preview.promote }.to change { page_preview.parent }.from(page).to(nil).and change { Spree::Page.count }.by(-1)

      expect(page_preview.reload.preview?).to be(false)
    end
  end
end
