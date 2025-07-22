require 'spec_helper'

describe Spree::Theme, type: :model do
  let(:store) { @default_store }
  let(:theme) { create(:theme, store: store) }

  context 'Callbacks' do
    describe '#touch' do
      it 'touches store' do
        expect { theme.update!(name: 'New Name') }.to change { store.reload.updated_at }
      end
    end

    describe '#ensure_default_exists_and_is_unique' do
      context 'when default is true' do
        let!(:default_theme) { create(:theme, store: store, default: true) }

        it 'should set default to false for other themes' do
          expect { theme.update!(default: true) }.to change { default_theme.reload.default }.from(true).to(false)
        end

        it 'should touch cache for other themes' do
          expect { theme.update!(default: true) }.to change { default_theme.reload.cache_key_with_version }
        end
      end

      context 'when default is false' do
        let!(:default_theme) { create(:theme, store: store, default: true) }

        it 'should not change default to false for other themes' do
          expect { theme.update!(name: 'New Name') }.not_to change { default_theme.reload.default }
        end

        it 'should not touch cache for other themes' do
          expect { theme.update!(name: 'New Name') }.not_to change { default_theme.reload.cache_key_with_version }
        end
      end
    end
  end

  describe '#create_preview' do
    it 'should create a preview' do
      expect { theme.create_preview }.to change { theme.previews.count }.by(1)

      new_preview = theme.previews.last
      expect(new_preview).to be_present
      expect(new_preview.parent).to eq(theme)

      expect(new_preview.name).to eq(theme.name)
      expect(new_preview.preferences).to eq(theme.preferences)
      expect(new_preview.preferences.count).to eq(theme.preferences.count)
    end
  end

  describe '#promote' do
    let!(:theme_preview) { theme.create_preview }

    it 'should promote the preview to the main theme' do
      page_ids = theme.pages.pluck(:id)

      expect { theme_preview.promote }.to change { theme_preview.parent }.from(theme).to(nil).and change { Spree::Theme.count }.by(-1)

      expect(theme_preview.reload.preview?).to be(false)
      expect(theme_preview.parent).to be_nil

      expect(theme_preview.page_ids).to contain_exactly(*page_ids)
    end

    context 'when screenshot_api_token is not set' do
      before do
        Spree.screenshot_api_token = nil
      end

      it 'does not take a screenshot' do
        expect { theme.take_screenshot }.not_to have_enqueued_job(Spree::Themes::ScreenshotJob)
      end
    end

    context 'when screenshot_api_token is set' do
      before do
        Spree.screenshot_api_token = 'test_token'
      end

      after do
        Spree.screenshot_api_token = nil
      end

      it 'takes a screenshot' do
        expect { theme.take_screenshot }.to have_enqueued_job(Spree::Themes::ScreenshotJob)
      end
    end
  end
end
