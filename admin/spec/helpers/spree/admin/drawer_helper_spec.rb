require 'spec_helper'

describe Spree::Admin::DrawerHelper do
  describe '#drawer' do
    it 'renders a dialog element with drawer class' do
      result = helper.drawer { 'content' }

      expect(result).to have_css('dialog.drawer[data-drawer-target="dialog"]')
      expect(result).to include('content')
    end

    it 'renders with custom id' do
      result = helper.drawer(id: 'my-drawer') { 'content' }

      expect(result).to have_css('dialog#my-drawer')
    end

    it 'renders with custom controller name' do
      result = helper.drawer(controller_name: 'dialog') { 'content' }

      expect(result).to have_css('dialog[data-dialog-target="dialog"]')
    end

    it 'merges additional data attributes' do
      result = helper.drawer(data: { controller: 'filters' }) { 'content' }

      expect(result).to have_css('dialog[data-controller="filters"]')
      expect(result).to have_css('dialog[data-drawer-target="dialog"]')
    end

    it 'merges additional CSS classes' do
      result = helper.drawer(class: 'custom-class') { 'content' }

      expect(result).to have_css('dialog.drawer.custom-class')
    end
  end

  describe '#drawer_header' do
    it 'renders a drawer header with title' do
      result = helper.drawer_header('Test Title')

      expect(result).to have_css('.drawer-header')
      expect(result).to have_css('.drawer-title', text: 'Test Title')
      expect(result).to have_css('.btn-close')
    end

    it 'uses default controller name for close button' do
      result = helper.drawer_header('Test Title')

      expect(result).to have_css('[data-action="drawer#close"]')
    end

    it 'uses custom controller name for close button' do
      result = helper.drawer_header('Test Title', 'dialog')

      expect(result).to have_css('[data-action="dialog#close"]')
    end
  end

  describe '#drawer_close_button' do
    it 'renders a close button with default controller' do
      result = helper.drawer_close_button

      expect(result).to have_css('button.btn-close[data-action="drawer#close"]')
    end

    it 'renders a close button with custom controller' do
      result = helper.drawer_close_button('dialog')

      expect(result).to have_css('button.btn-close[data-action="dialog#close"]')
    end
  end

  describe '#drawer_discard_button' do
    it 'renders a discard button with default controller' do
      result = helper.drawer_discard_button

      expect(result).to have_css('button.btn.btn-light[data-action="drawer#close"]')
      expect(result).to include(Spree.t('actions.discard'))
    end

    it 'renders a discard button with custom controller' do
      result = helper.drawer_discard_button('dialog')

      expect(result).to have_css('button[data-action="dialog#close"]')
    end
  end
end
