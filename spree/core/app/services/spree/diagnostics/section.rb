module Spree
  class Diagnostics
    # One part of the diagnostics report. A subclass names its rows; each row
    # is read separately and reports "unavailable" when reading it fails, since
    # a half-broken installation is exactly when the report is needed.
    #
    # Everything a row returns ends up in a public GitHub issue, so a row adds
    # one deliberately chosen fact: never a name, URL, email or credential, and
    # records only by prefixed ID.
    #
    #   class MyGem::DiagnosticsSection < Spree::Diagnostics::Section
    #     def title = 'My gem'
    #
    #     def rows
    #       { 'Mode' => -> { MyGem.config.mode } }
    #     end
    #   end
    #
    #   Spree.diagnostics_sections << 'MyGem::DiagnosticsSection'
    class Section
      UNAVAILABLE = 'unavailable'.freeze

      attr_reader :store

      # @param store [Spree::Store]
      def initialize(store)
        @store = store
      end

      # @return [String]
      def key
        self.class.name.demodulize.underscore
      end

      # @return [String]
      def title
        raise NotImplementedError
      end

      # @return [Hash{String => Proc}] label => reader
      def rows
        raise NotImplementedError
      end

      # @return [Array<Hash>] `{ label:, value: }`, values as strings
      def to_rows
        rows.filter_map do |label, reader|
          value = read(reader)
          { label: label, value: value } unless value.nil?
        end
      end

      private

      def read(reader)
        format_value(reader.call)
      rescue StandardError
        UNAVAILABLE
      end

      def format_value(value)
        case value
        when nil then nil
        when true then 'yes'
        when false then 'no'
        when Array then value.compact_blank.join(', ').presence || 'none'
        else value.to_s
        end
      end
    end
  end
end
