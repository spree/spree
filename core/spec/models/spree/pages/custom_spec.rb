require 'spec_helper'

describe Spree::Pages::Custom do
  describe '#create' do
    let(:page) { create(:custom_page, name: 'Custom Page Title') }

    it 'should be created with default sections' do
      expect(page.sections.count).to eq 2
      expect(page.sections.map(&:display_name)).to contain_exactly(
        'Custom Page Title', 'Rich Text'
      )
    end
  end

  describe '#promote', job: true do
    let!(:custom_page) { create(:custom_page, name: 'Custom Page Title') }
    let!(:page_preview) { custom_page.create_preview }

    before do
      page_preview.update(slug: 'some-other-slug')
    end

    it 'should promote the preview to the main page' do
      expect do
        perform_enqueued_jobs { page_preview.promote }
      end.to change { page_preview.parent }.from(custom_page).to(nil).and change { Spree::Page.count }.by(-1)

      expect(page_preview.reload.preview?).to be(false)
      expect(page_preview.slug).to eq(custom_page.slug)
      expect(page_preview).not_to be_deleted
      expect(custom_page.reload).to be_deleted
    end
  end
end
