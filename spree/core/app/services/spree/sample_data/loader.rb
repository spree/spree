module Spree
  module SampleData
    class Loader
      prepend Spree::ServiceModule::Base
      include Spree::SampleData::Helper

      def call
        Spree::Events.disable do
          without_geocoding do
            ActiveRecord::Base.no_touching do
              puts 'Running seeds first...' unless seeds_loaded?
              ensure_seeds_loaded

              puts 'Loading sample configuration data...'
              load_configuration_data

              puts 'Loading sample markets...'
              load_ruby_file('markets')

              puts 'Loading sample channels...'
              load_ruby_file('channels')

              puts 'Loading sample custom_field definitions...'
              load_ruby_file('custom_field_definitions')

              puts 'Loading sample options...'
              load_ruby_file('options')

              puts 'Loading sample product types...'
              load_ruby_file('product_types')

              puts 'Loading sample products...'
              load_products

              puts 'Publishing sample products on the default channel...'
              publish_sample_products(Spree::Store.default)

              puts 'Loading sample product translations...'
              load_product_translations

              puts 'Linking product types to categories...'
              load_ruby_file('product_type_categories')

              puts 'Loading sample collections...'
              load_ruby_file('collections')

              puts 'Loading sample customers...'
              load_customers

              puts 'Loading wholesale demo data...'
              load_ruby_file('wholesale')

              puts 'Loading sample orders...'
              load_ruby_file('orders')

              puts 'Loading sample posts...'
              load_ruby_file('posts')

              puts 'Sample data loaded successfully!'
            end
          end
        end
      end

      private

      def load_configuration_data
        load_ruby_file('shipping_methods')
        load_ruby_file('payment_methods')
        load_ruby_file('promotions')
      end

      def load_products
        csv_path = sample_data_path.join('products.csv')
        Spree::SampleData::ImportRunner.call(csv_path: csv_path, import_class: Spree::Imports::Products, inline: true)
      end

      def load_product_translations
        csv_path = sample_data_path.join('product_translations.csv')
        return unless csv_path.exist?

        Spree::SampleData::ImportRunner.call(csv_path: csv_path, import_class: Spree::Imports::ProductTranslations, inline: true)
      end

      def load_customers
        csv_path = sample_data_path.join('customers.csv')
        Spree::SampleData::ImportRunner.call(csv_path: csv_path, import_class: Spree::Imports::Customers, inline: true)
      end
    end
  end
end
