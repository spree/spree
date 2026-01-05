module Spree
  module Admin
    class RecordList
      class Builder
        attr_reader :registry, :parent_column

        def initialize(registry, parent_column = nil)
          @registry = registry
          @parent_column = parent_column
        end

        # Add a column
        # @param key [Symbol] column key
        # @param options [Hash] column options
        # @return [Column]
        def add(key, **options, &block)
          @registry.add(key, **options, &block)
        end

        # Remove a column
        # @param key [Symbol] column key
        # @return [Column, nil]
        def remove(key)
          @registry.remove(key)
        end

        # Update a column
        # @param key [Symbol] column key
        # @param options [Hash] attributes to update
        # @return [Column, nil]
        def update(key, **options)
          @registry.update(key, **options)
        end

        # Insert before another column
        # @param target_key [Symbol] existing column key
        # @param new_key [Symbol] new column key
        # @param options [Hash] column options
        # @return [Column, nil]
        def insert_before(target_key, new_key, **options)
          @registry.insert_before(target_key, new_key, **options)
        end

        # Insert after another column
        # @param target_key [Symbol] existing column key
        # @param new_key [Symbol] new column key
        # @param options [Hash] column options
        # @return [Column, nil]
        def insert_after(target_key, new_key, **options)
          @registry.insert_after(target_key, new_key, **options)
        end
      end
    end
  end
end
