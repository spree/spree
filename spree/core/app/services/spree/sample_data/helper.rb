module Spree
  module SampleData
    # Shared by the sample-data drivers: `Spree::SampleData::Loader` (the
    # synchronous, rake-facing one) and any app that loads a subset itself —
    # e.g. running the configuration files inline and handing the CSVs to the
    # import pipeline. Keeping the file locations and catalog-publishing rules
    # here means they don't have to be kept in sync by hand.
    module Helper
      private

      def sample_data_path
        @sample_data_path ||= Spree::Core::Engine.root.join('db', 'sample_data')
      end

      def load_ruby_file(name)
        file = sample_data_path.join("#{name}.rb")
        load file.to_s if file.exist?
      end

      # Publishes the catalog to every channel the store has. The import only
      # adds a product to the default channel, and only when it has none, so
      # anything else the store defines (wholesale, a locale-specific storefront,
      # whatever an app has seeded) would otherwise be left empty. Catalog parity
      # is the point — channels differentiate through their own gates and price
      # lists, not through a narrower catalog. `add_products` upserts in bulk and
      # skips rows that already exist.
      def publish_sample_products(store)
        product_ids = store.product_ids
        return if product_ids.empty?

        store.channels.each { |channel| channel.add_products(product_ids) }
      end

      # Cheap proxy for "the base seeds have run". Countries and states are
      # reference data now, so the marker is a seeded role instead.
      def seeds_loaded?
        Spree::Role.exists?(name: 'admin')
      end

      def ensure_seeds_loaded
        return if seeds_loaded?

        Spree::Seeds::All.call
      end

      def without_geocoding
        previous = Spree::Config[:geocode_addresses]
        Spree::Config[:geocode_addresses] = false
        yield
      ensure
        Spree::Config[:geocode_addresses] = previous
      end
    end
  end
end
