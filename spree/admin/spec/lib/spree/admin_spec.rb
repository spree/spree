require 'spec_helper'

RSpec.describe Spree do
  describe '.admin' do
    it 'returns an AdminConfig instance' do
      expect(Spree.admin).to be_a(Spree::AdminConfig)
    end

    it 'returns the same instance on subsequent calls' do
      first_call = Spree.admin
      second_call = Spree.admin

      expect(first_call).to be(second_call)
    end
  end

  describe Spree::AdminConfig do
    subject(:admin_config) { Spree.admin }

    describe '#navigation' do
      it 'delegates to Rails.application.config.spree_admin.navigation' do
        expect(admin_config.navigation).to eq(Rails.application.config.spree_admin.navigation)
      end

      it 'allows accessing sidebar navigation' do
        expect(admin_config.navigation.sidebar).to be_a(Spree::Admin::Navigation)
      end

      it 'allows accessing settings navigation' do
        expect(admin_config.navigation.settings).to be_a(Spree::Admin::Navigation)
      end

      it 'allows accessing predefined tab contexts' do
        expect(admin_config.navigation.tax_tabs).to be_a(Spree::Admin::Navigation)
        expect(admin_config.navigation.shipping_tabs).to be_a(Spree::Admin::Navigation)
      end

      it 'allows registering custom navigation contexts' do
        brand_tabs = admin_config.navigation.register_context(:brand_tabs)

        expect(brand_tabs).to be_a(Spree::Admin::Navigation)
        expect(brand_tabs.context).to eq(:brand_tabs)
      end

      it 'returns the same instance for repeated access to registered contexts' do
        admin_config.navigation.register_context(:inventory_tabs)
        first_access = admin_config.navigation.inventory_tabs
        second_access = admin_config.navigation.inventory_tabs

        expect(first_access).to be(second_access)
      end

      it 'allows adding items to custom navigation contexts' do
        custom_tabs = admin_config.navigation.register_context(:custom_tabs)
        custom_tabs.add :tab1, label: 'Tab 1', url: '/tab1'

        expect(custom_tabs.find(:tab1)).to be_present

        # Cleanup
        custom_tabs.remove(:tab1)
      end

      it 'raises NoMethodError when accessing unregistered context' do
        expect {
          admin_config.navigation.nonexistent_context
        }.to raise_error(NoMethodError, /Navigation context 'nonexistent_context' has not been registered/)
      end

      it 'allows adding items to sidebar navigation' do
        sidebar = admin_config.navigation.sidebar
        sidebar.add :test_item, label: 'Test', url: '/test'

        expect(sidebar.find(:test_item)).to be_present

        # Cleanup
        sidebar.remove(:test_item)
      end
    end

    describe Spree::Admin::Engine::NavigationEnvironment do
      subject(:nav_env) { described_class.new }

      describe '#register_context' do
        it 'creates and returns a navigation context' do
          result = nav_env.register_context(:my_context)

          expect(result).to be_a(Spree::Admin::Navigation)
          expect(result.context).to eq(:my_context)
        end

        it 'returns the same instance on subsequent calls' do
          first = nav_env.register_context(:my_context)
          second = nav_env.register_context(:my_context)

          expect(first).to be(second)
        end

        it 'accepts string or symbol names' do
          nav_env.register_context('string_context')

          expect(nav_env.context?(:string_context)).to be true
        end
      end

      describe '#get_context' do
        it 'returns a registered context' do
          nav_env.register_context(:sidebar)
          result = nav_env.get_context(:sidebar)

          expect(result).to be_a(Spree::Admin::Navigation)
        end

        it 'raises NoMethodError for unregistered context' do
          expect {
            nav_env.get_context(:nonexistent)
          }.to raise_error(NoMethodError, /Navigation context 'nonexistent' has not been registered/)
        end
      end

      describe '#contexts' do
        it 'returns list of registered contexts' do
          nav_env.register_context(:sidebar)
          nav_env.register_context(:settings)
          nav_env.register_context(:custom_tabs)

          expect(nav_env.contexts).to contain_exactly(:sidebar, :settings, :custom_tabs)
        end
      end

      describe '#context?' do
        it 'returns true for registered contexts' do
          nav_env.register_context(:sidebar)

          expect(nav_env.context?(:sidebar)).to be true
        end

        it 'returns false for unregistered contexts' do
          expect(nav_env.context?(:nonexistent)).to be false
        end
      end

      describe 'dynamic accessor methods' do
        it 'allows accessing registered contexts via method calls' do
          nav_env.register_context(:my_tabs)

          expect(nav_env.my_tabs).to be_a(Spree::Admin::Navigation)
        end

        it 'raises NoMethodError for unregistered contexts' do
          expect {
            nav_env.unregistered_context
          }.to raise_error(NoMethodError)
        end
      end
    end

    describe '#partials' do
      it 'returns a Spree::Core::Partials instance' do
        expect(admin_config.partials).to be_a(Spree::Core::Partials)
      end
    end
  end
end
