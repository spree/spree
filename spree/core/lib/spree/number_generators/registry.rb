module Spree
  module NumberGenerators
    # Maps a resource key (`:order`, `:return`, …) to the generator that
    # numbers it. Empty by default: with no explicit entry, the store's
    # `document_number_format` preference decides between the sequential and
    # random strategies, which is what makes the dashboard switch work
    # without any registration at all.
    #
    #   Spree.number_generators[:order] = 'MyApp::BranchOrderNumbers'
    #   Spree.number_generators[:order]        # => the class
    #   Spree.number_generators.delete(:order) # back to store settings
    #
    # Values are stored as strings and constantized on read so a host app can
    # register in an initializer without eager-loading the class, and so
    # Zeitwerk reloads resolve the current definition in development.
    class Registry
      FORMATS = {
        'sequential' => 'Spree::NumberGenerators::Sequential',
        'random' => 'Spree::NumberGenerators::Random'
      }.freeze

      DEFAULT_FORMAT = 'sequential'.freeze

      def initialize
        @overrides = {}
      end

      # @param key [Symbol, String] resource key
      # @param class_name [String, Class, nil] nil clears the override
      def []=(key, class_name)
        if class_name.nil?
          delete(key)
        else
          @overrides[key.to_sym] = class_name.to_s
        end
      end

      # @return [Class, nil] the registered class, without falling back
      def [](key)
        @overrides[key.to_sym]&.constantize
      end

      def delete(key)
        @overrides.delete(key.to_sym)
      end

      def keys
        @overrides.keys
      end

      def clear
        @overrides.clear
      end

      # The generator for a resource: an explicit registration if there is
      # one, otherwise the strategy named by the format preference of the
      # store the record belongs to.
      #
      # @param key [Symbol, String] resource key
      # @param store [Spree::Store, nil] the record's store; the format
      #   preference is read from it rather than from `Spree::Current` so a
      #   background job numbering another store's document still honours
      #   that store's choice
      # @return [Spree::NumberGenerators::Base]
      def for(key, store: nil)
        registered = self[key]
        return registered.new if registered

        format_class(store).new
      end

      private

      def format_class(store)
        format = (store || Spree::Current.store)&.preferred_document_number_format
        FORMATS.fetch(format.to_s, FORMATS.fetch(DEFAULT_FORMAT)).constantize
      end
    end
  end
end
