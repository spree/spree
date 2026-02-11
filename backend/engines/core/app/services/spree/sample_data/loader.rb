module Spree
  module SampleData
    class Loader
      prepend Spree::ServiceModule::Base

      def call
        Spree::Events.disable do
          ensure_seeds_loaded

          puts 'Loading sample configuration data...'
          load_configuration_data

          puts 'Loading sample products...'
          load_products

          puts 'Loading sample customers...'
          load_customers

          puts 'Loading sample stock...'
          load_ruby_file('stock')

          puts 'Loading sample orders...'
          load_ruby_file('orders')

          puts 'Loading sample metafields...'
          load_ruby_file('metafields')

          puts 'Loading sample posts...'
          load_ruby_file('posts')

          puts 'Sample data loaded successfully!'
        end
      end

      private

      def ensure_seeds_loaded
        us = Spree::Country.find_by(iso: 'US')
        return if us&.states&.any? && Spree::Store.default&.persisted?

        puts 'Running seeds first...'
        Spree::Seeds::All.call
      end

      def sample_data_path
        @sample_data_path ||= Spree::Core::Engine.root.join('db', 'sample_data')
      end

      def load_configuration_data
        load_ruby_file('zones')
        load_ruby_file('tax_categories')
        load_ruby_file('tax_rates')
        load_ruby_file('shipping_methods')
        load_ruby_file('payment_methods')
        load_ruby_file('promotions')
      end

      def load_products
        csv_path = sample_data_path.join('products.csv')
        Spree::SampleData::ImportRunner.call(csv_path: csv_path, import_class: Spree::Imports::Products)
      end

      def load_customers
        csv_path = sample_data_path.join('customers.csv')
        Spree::SampleData::ImportRunner.call(csv_path: csv_path, import_class: Spree::Imports::Customers)
      end

      def load_ruby_file(name)
        file = sample_data_path.join("#{name}.rb")
        load file.to_s if file.exist?
      end
    end
  end
end
