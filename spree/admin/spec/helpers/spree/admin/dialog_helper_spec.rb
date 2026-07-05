require 'spec_helper'

describe Spree::Admin::DialogHelper do
  describe '#dialog' do
    it 'renders a dialog element with default attributes' do
      result = helper.dialog { 'content' }

      expect(result).to have_css('dialog.dialog[data-dialog-target="dialog"]')
      expect(result).to include('content')
    end

    it 'renders with custom id' do
      result = helper.dialog(id: 'my-dialog') { 'content' }

      expect(result).to have_css('dialog#my-dialog')
    end

    it 'renders with custom controller name' do
      result = helper.dialog(controller_name: 'custom-dialog') { 'content' }

      expect(result).to have_css('dialog[data-custom-dialog-target="dialog"]')
    end

    it 'merges additional data attributes' do
      result = helper.dialog(data: { controller: 'search-picker' }) { 'content' }

      expect(result).to have_css('dialog[data-controller="search-picker"]')
      expect(result).to have_css('dialog[data-dialog-target="dialog"]')
    end

    it 'merges additional CSS classes' do
      result = helper.dialog(class: 'custom-class') { 'content' }

      expect(result).to have_css('dialog.dialog.custom-class')
    end
  end

  describe '#dialog_header' do
    it 'renders a dialog header with title' do
      result = helper.dialog_header('Test Title')

      expect(result).to have_css('.dialog-header')
      expect(result).to have_css('.dialog-title', text: 'Test Title')
      expect(result).to have_css('.btn-close')
    end

    it 'uses default controller name for close button' do
      result = helper.dialog_header('Test Title')

      expect(result).to have_css('[data-action="dialog#close"]')
    end

    it 'uses custom controller name for close button' do
      result = helper.dialog_header('Test Title', 'custom-dialog')

      expect(result).to have_css('[data-action="custom-dialog#close"]')
    end
  end

  describe '#dialog_close_button' do
    it 'renders a close button with default controller' do
      result = helper.dialog_close_button

      expect(result).to have_css('button.btn-close[data-action="dialog#close"]')
    end

    it 'renders a close button with custom controller' do
      result = helper.dialog_close_button('my-dialog')

      expect(result).to have_css('button.btn-close[data-action="my-dialog#close"]')
    end
  end

  describe '#dialog_discard_button' do
    it 'renders a discard button with default controller' do
      result = helper.dialog_discard_button

      expect(result).to have_css('button.btn.btn-light[data-action="dialog#close"]')
      expect(result).to include(Spree.t('actions.discard'))
    end

    it 'renders a discard button with custom controller' do
      result = helper.dialog_discard_button('my-dialog')

      expect(result).to have_css('button[data-action="my-dialog#close"]')
    end
  end
end
