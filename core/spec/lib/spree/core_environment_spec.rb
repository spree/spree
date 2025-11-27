require 'spec_helper'

RSpec.describe 'Spree environment accessors' do
  describe 'getter methods' do
    it 'provides access to calculators' do
      expect(Spree.calculators).to eq(Rails.application.config.spree.calculators)
      expect(Spree.calculators).to respond_to(:shipping_methods)
      expect(Spree.calculators).to respond_to(:tax_rates)
    end

    it 'provides access to validators' do
      expect(Spree.validators).to eq(Rails.application.config.spree.validators)
      expect(Spree.validators).to respond_to(:addresses)
    end

    it 'provides access to payment_methods' do
      expect(Spree.payment_methods).to eq(Rails.application.config.spree.payment_methods)
      expect(Spree.payment_methods).to be_an(Array)
    end

    it 'provides access to adjusters' do
      expect(Spree.adjusters).to eq(Rails.application.config.spree.adjusters)
      expect(Spree.adjusters).to be_an(Array)
    end

    it 'provides access to stock_splitters' do
      expect(Spree.stock_splitters).to eq(Rails.application.config.spree.stock_splitters)
      expect(Spree.stock_splitters).to be_an(Array)
    end

    it 'provides access to promotions' do
      expect(Spree.promotions).to eq(Rails.application.config.spree.promotions)
      expect(Spree.promotions).to respond_to(:rules)
      expect(Spree.promotions).to respond_to(:actions)
    end

    it 'provides access to line_item_comparison_hooks' do
      expect(Spree.line_item_comparison_hooks).to eq(Rails.application.config.spree.line_item_comparison_hooks)
    end

    it 'provides access to data_feed_types' do
      expect(Spree.data_feed_types).to eq(Rails.application.config.spree.data_feed_types)
      expect(Spree.data_feed_types).to be_an(Array)
    end

    it 'provides access to export_types' do
      expect(Spree.export_types).to eq(Rails.application.config.spree.export_types)
      expect(Spree.export_types).to be_an(Array)
    end

    it 'provides access to import_types' do
      expect(Spree.import_types).to eq(Rails.application.config.spree.import_types)
      expect(Spree.import_types).to be_an(Array)
    end

    it 'provides access to taxon_rules' do
      expect(Spree.taxon_rules).to eq(Rails.application.config.spree.taxon_rules)
      expect(Spree.taxon_rules).to be_an(Array)
    end

    it 'provides access to reports' do
      expect(Spree.reports).to eq(Rails.application.config.spree.reports)
      expect(Spree.reports).to be_an(Array)
    end

    it 'provides access to translatable_resources' do
      expect(Spree.translatable_resources).to eq(Rails.application.config.spree.translatable_resources)
      expect(Spree.translatable_resources).to be_an(Array)
    end

    it 'provides access to metafields.types' do
      expect(Spree.metafields.types).to eq(Rails.application.config.spree.metafields.types)
      expect(Spree.metafields.types).to be_an(Array)
    end

    it 'provides access to metafields.enabled_resources' do
      expect(Spree.metafields.enabled_resources).to eq(Rails.application.config.spree.metafields.enabled_resources)
      expect(Spree.metafields.enabled_resources).to be_an(Array)
    end

    it 'provides access to analytics.events' do
      expect(Spree.analytics.events).to eq(Rails.application.config.spree.analytics_events)
      expect(Spree.analytics.events).to be_a(Hash)
    end

    it 'provides access to analytics.handlers' do
      expect(Spree.analytics.handlers).to eq(Rails.application.config.spree.analytics_event_handlers)
      expect(Spree.analytics.handlers).to be_an(Array)
    end

    it 'provides access to integrations' do
      expect(Spree.integrations).to eq(Rails.application.config.spree.integrations)
      expect(Spree.integrations).to be_an(Array)
    end
  end

  describe 'setter methods' do
    it 'allows setting payment_methods' do
      original = Spree.payment_methods.dup
      Spree.payment_methods = ['Custom::PaymentMethod']
      expect(Spree.payment_methods).to eq(['Custom::PaymentMethod'])
      expect(Rails.application.config.spree.payment_methods).to eq(['Custom::PaymentMethod'])
      # Restore original
      Spree.payment_methods = original
    end

    it 'allows setting stock_splitters' do
      original = Spree.stock_splitters.dup
      Spree.stock_splitters = ['Custom::Splitter']
      expect(Spree.stock_splitters).to eq(['Custom::Splitter'])
      expect(Rails.application.config.spree.stock_splitters).to eq(['Custom::Splitter'])
      # Restore original
      Spree.stock_splitters = original
    end

    it 'allows setting reports' do
      original = Spree.reports.dup
      Spree.reports = ['Custom::Report']
      expect(Spree.reports).to eq(['Custom::Report'])
      expect(Rails.application.config.spree.reports).to eq(['Custom::Report'])
      # Restore original
      Spree.reports = original
    end
  end

  describe 'nested accessors' do
    it 'allows access to calculators.shipping_methods' do
      expect(Spree.calculators.shipping_methods).to eq(Rails.application.config.spree.calculators.shipping_methods)
      expect(Spree.calculators.shipping_methods).to be_an(Array)
      expect(Spree.calculators.shipping_methods).to include(Spree::Calculator::Shipping::FlatRate)
    end

    it 'allows access to calculators.tax_rates' do
      expect(Spree.calculators.tax_rates).to eq(Rails.application.config.spree.calculators.tax_rates)
      expect(Spree.calculators.tax_rates).to be_an(Array)
    end

    it 'allows access to promotions.rules' do
      expect(Spree.promotions.rules).to eq(Rails.application.config.spree.promotions.rules)
      expect(Spree.promotions.rules).to be_an(Array)
    end

    it 'allows access to promotions.actions' do
      expect(Spree.promotions.actions).to eq(Rails.application.config.spree.promotions.actions)
      expect(Spree.promotions.actions).to be_an(Array)
    end

    it 'allows access to validators.addresses' do
      expect(Spree.validators.addresses).to eq(Rails.application.config.spree.validators.addresses)
      expect(Spree.validators.addresses).to be_an(Array)
    end
  end

  describe 'modifying nested values' do
    it 'allows modifying calculators.shipping_methods' do
      original = Spree.calculators.shipping_methods.dup
      Spree.calculators.shipping_methods << 'Custom::ShippingCalculator'
      expect(Spree.calculators.shipping_methods).to include('Custom::ShippingCalculator')
      # Restore original
      Spree.calculators.shipping_methods.clear
      Spree.calculators.shipping_methods.concat(original)
    end

    it 'allows modifying promotions.rules' do
      original = Spree.promotions.rules.dup
      Spree.promotions.rules << 'Custom::PromotionRule'
      expect(Spree.promotions.rules).to include('Custom::PromotionRule')
      # Restore original
      Spree.promotions.rules.clear
      Spree.promotions.rules.concat(original)
    end
  end

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
