module Spree
  module TranslatableResourceScopes
    extend ActiveSupport::Concern

    class_methods do
      # To be used when joining on the resource itself does not automatically join on its translations table
      # This method is to be used when you've already joined on the translatable table itself
      #
      # If the resource table is aliased, pass the alias to `join_on_table_alias`, otherwise omit the param
      def join_translation_table(translatable_class, join_on_table_alias = nil)
        join_on_table_name = if join_on_table_alias.nil?
                               translatable_class.table_name
                             else
                               join_on_table_alias
                             end
        translatable_class_foreign_key = "#{translatable_class.table_name.singularize}_id"

        joins(
          Arel::Nodes::OuterJoin.new(
            Arel::Table.new(translatable_class::Translation.table_name).alias(translatable_class.translation_table_alias),
            Arel::Nodes::On.new(
              Arel::Nodes::And.new([
                Arel::Nodes::Equality.new(
                  Arel::Table.new(translatable_class.translation_table_alias)[translatable_class_foreign_key],
                  Arel::Table.new(join_on_table_name)[:id]
                ),
                Arel::Nodes::Equality.new(
                  Arel::Table.new(translatable_class.translation_table_alias)[:locale],
                  Arel::Nodes::Quoted.new(Mobility.locale.to_s)
                )
              ])
            )
          )
        )
      end
    end
  end
end
