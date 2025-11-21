require 'spec_helper'

describe Spree::Admin::NavigationHelper, type: :helper do
  describe '#link_to_edit' do
    let(:resource) { double('Resource') }

    before do
      allow(helper).to receive(:can?).and_return(true)
      allow(helper).to receive(:edit_object_url).with(resource).and_return('/edit/resource')
      allow(helper).to receive(:link_to_with_icon).and_return('link')
    end

    it 'calls link_to_with_icon with pencil icon' do
      expect(helper).to receive(:link_to_with_icon).with('pencil', Spree.t(:edit), '/edit/resource', anything)
      helper.link_to_edit(resource)
    end

    it 'returns nil if user cannot update resource' do
      allow(helper).to receive(:can?).and_return(false)
      expect(helper.link_to_edit(resource)).to be_nil
    end
  end

  describe '#link_to_delete' do
    let(:resource) { double('Resource') }

    before do
      allow(helper).to receive(:can?).and_return(true)
      allow(helper).to receive(:object_url).with(resource).and_return('/resource')
      allow(helper).to receive(:link_to_with_icon).and_return('link')
      allow(helper).to receive(:link_to).and_return('link')
    end

    it 'returns nil if user cannot destroy resource' do
      allow(helper).to receive(:can?).and_return(false)
      expect(helper.link_to_delete(resource)).to be_nil
    end

    it 'uses link_to_with_icon when no_text option is true' do
      expect(helper).to receive(:link_to_with_icon).with('trash', anything, '/resource', hash_including(no_text: true))
      helper.link_to_delete(resource, no_text: true)
    end

    it 'uses link_to_with_icon when icon option is provided' do
      expect(helper).to receive(:link_to_with_icon).with('custom-icon', anything, '/resource', hash_including(icon: 'custom-icon'))
      helper.link_to_delete(resource, icon: 'custom-icon')
    end

    it 'uses link_to when no icon options are provided' do
      expect(helper).to receive(:link_to).with(Spree.t('actions.destroy'), '/resource', anything)
      helper.link_to_delete(resource)
    end
  end

  describe '#button' do
    it 'creates a button with spinner for turbo' do
      result = helper.button('Submit', 'save')
      expect(result).to include('data-turbo-submits-with')
      expect(result).to include('spinner-border')
    end
  end

  describe '#active_badge' do
    it 'returns active badge when condition is true' do
      result = helper.active_badge(true)
      expect(result).to include('badge-active')
    end

    it 'returns inactive badge when condition is false' do
      result = helper.active_badge(false)
      expect(result).to include('badge-inactive')
    end
  end

  describe '#page_header_back_button' do
    before do
      allow(helper).to receive(:session).and_return({})
      allow(helper).to receive(:icon).and_return('icon')
    end

    it 'returns link to default url when no object is provided' do
      expect(helper.page_header_back_button('/default')).to include('/default')
    end

    it 'returns link to session url when object is provided and session key exists' do
      object = Spree::Product.new
      allow(helper).to receive(:session).and_return(products_return_to: '/from_session')
      expect(helper.page_header_back_button('/default', object)).to include('/from_session')
    end
  end

  describe '#external_page_preview_link' do
    let(:current_store) { create(:store) }
    let(:product) { create(:product, stores: [current_store]) }

    def spree_storefront_resource_url(*_args); end
    def button_link_to(*_args); end
    def link_to_with_icon(*_args); end

    context 'for product' do
      context 'when product is a draft' do
        before { product.update(status: :draft) }

        it 'should call spree_storefront_resource_url with preview_id' do
          expect(self).to receive(:spree_storefront_resource_url).with(product, preview_id: product.id)

          external_page_preview_link(product)
        end
      end

      context 'when product is not a draft' do
        it 'should call spree_storefront_resource_url with preview_id' do
          expect(self).to receive(:spree_storefront_resource_url).with(product, preview_id: product.id)

          external_page_preview_link(product)
        end
      end
    end
  end

  describe '#render_navigation' do
    before do
      Spree::Admin::Navigation.clear_all!
      allow(Spree::Admin::RuntimeConfig).to receive(:legacy_sidebar_navigation).and_return(false)
    end

    it 'returns empty string when legacy navigation is enabled' do
      allow(Spree::Admin::RuntimeConfig).to receive(:legacy_sidebar_navigation).and_return(true)

      expect(helper.render_navigation(:sidebar)).to eq('')
    end

    it 'returns empty string when no items are visible' do
      Spree::Admin::Navigation.configure(:sidebar) do |nav|
        nav.add :dashboard, label: 'Dashboard', if: -> { false }
      end

      expect(helper.render_navigation(:sidebar)).to eq('')
    end

    it 'renders navigation partial when items are visible' do
      Spree::Admin::Navigation.configure(:sidebar) do |nav|
        nav.add :dashboard, label: 'Dashboard', url: '/admin'
      end

      allow(helper).to receive(:render).and_return('navigation html')

      result = helper.render_navigation(:sidebar)

      expect(result).to eq('navigation html')
    end
  end

  describe '#navigation_items' do
    before do
      Spree::Admin::Navigation.clear_all!
    end

    it 'returns visible items for the given context' do
      Spree::Admin::Navigation.configure(:sidebar) do |nav|
        nav.add :dashboard, label: 'Dashboard', url: '/admin'
        nav.add :products, label: 'Products', url: '/admin/products'
      end

      items = helper.navigation_items(:sidebar)

      expect(items.size).to eq(2)
      expect(items.map(&:key)).to contain_exactly(:dashboard, :products)
    end

    it 'passes view context for permission checking' do
      allow(helper).to receive(:can?).with(:manage, Spree::Product).and_return(false)

      Spree::Admin::Navigation.configure(:sidebar) do |nav|
        nav.add :dashboard, label: 'Dashboard'
        nav.add :products, label: 'Products', if: -> { can?(:manage, Spree::Product) }
      end

      items = helper.navigation_items(:sidebar)

      expect(items.map(&:key)).to eq([:dashboard])
    end
  end

  describe '#current_navigation_context' do
    it 'returns :settings when in settings area' do
      allow(helper).to receive(:settings_area?).and_return(true)

      expect(helper.current_navigation_context).to eq(:settings)
    end

    it 'returns :sidebar when not in settings area' do
      allow(helper).to receive(:settings_area?).and_return(false)

      expect(helper.current_navigation_context).to eq(:sidebar)
    end
  end

  describe '#navigation_item_active?' do
    before do
      Spree::Admin::Navigation.clear_all!
      allow(helper).to receive(:request).and_return(double(path: '/admin/products'))
    end

    it 'returns true when item is active' do
      Spree::Admin::Navigation.configure(:sidebar) do |nav|
        nav.add :products, label: 'Products', url: '/admin/products'
      end

      expect(helper.navigation_item_active?(:products, :sidebar)).to be true
    end

    it 'returns false when item is not active' do
      Spree::Admin::Navigation.configure(:sidebar) do |nav|
        nav.add :dashboard, label: 'Dashboard', url: '/admin/orders'
      end

      expect(helper.navigation_item_active?(:dashboard, :sidebar)).to be false
    end

    it 'returns nil when item does not exist' do
      expect(helper.navigation_item_active?(:nonexistent, :sidebar)).to be_nil
    end
  end

  describe '#active_navigation_item' do
    before do
      Spree::Admin::Navigation.clear_all!
      allow(helper).to receive(:request).and_return(double(path: '/admin/products'))
      allow(helper).to receive(:settings_area?).and_return(false)
    end

    it 'returns the active navigation item for current path' do
      Spree::Admin::Navigation.configure(:sidebar) do |nav|
        nav.add :dashboard, label: 'Dashboard', url: '/admin/orders'
        nav.add :products, label: 'Products', url: '/admin/products'
      end

      active_item = helper.active_navigation_item

      expect(active_item.key).to eq(:products)
    end

    it 'returns nil when no item is active' do
      Spree::Admin::Navigation.configure(:sidebar) do |nav|
        nav.add :dashboard, label: 'Dashboard', url: '/admin/orders'
      end

      active_item = helper.active_navigation_item

      expect(active_item).to be_nil
    end
  end
end
