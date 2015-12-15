require 'active_record/connection_adapters/postgresql_adapter'

module Spree
  # @api private
  module ActiveRecordExt
    # Module to fix failing on unknown types
    module PostgreSQLConnectionAdapter

    private

      # Get type for oid
      #
      # @param [Fixnum] oid
      # @param [Fixnum] fmod
      # @param [String] column_name
      #
      # @return [Fixnum]
      def get_oid_type(oid, fmod, column_name)
        type_map.fetch(oid, fmod) do
          fail "unknown OID #{oid}: failed to recognize type of #{column_name.inspect}"
        end
      end

    end # PostgreSQLConnectionAdapter

    # Module to add identifier type support
    module IdentifierColumn
      SQL_TYPE = 'identifier'.freeze

    private

      # Look up the simplified field type based on the sql field type
      #
      # @param field_type [String]
      #
      # @return [Symbol]
      #   when the field type is known
      #
      # @return [nil]
      def simplified_type(field_type)
        field_type.eql?(SQL_TYPE) ? :integer : super
      end

    end # IdentifierColumn
  end # ActiveRecordExt
end # Spree

ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
  prepend(Spree::ActiveRecordExt::PostgreSQLConnectionAdapter)

  [
    [Spree::ActiveRecordExt::IdentifierColumn::SQL_TYPE, 'oid'],
    ['numeric_money',                                    'numeric'],
    ['discount_percentage',                              'numeric'],
    ['currency',                                         'string']
  ].each do |alias_from, alias_to|
    self::OID.alias_type(alias_from, alias_to)
  end
end

ActiveRecord::ConnectionAdapters::PostgreSQLColumn
  .prepend(Spree::ActiveRecordExt::IdentifierColumn)
