
module ActiveRecord
  class Base
    
    class << self
    
      # Interprets a polymorphic row from a unified SELECT, returning the appropriate ActiveRecord instance. Overrides ActiveRecord::Base.instantiate_without_callbacks.
      def instantiate_with_polymorphic_checks(record)
        if record['polymorphic_parent_class']
          reflection = record['polymorphic_parent_class'].constantize.reflect_on_association(record['polymorphic_association_id'].to_sym)
#          _logger_debug "Instantiating a polymorphic row for #{record['polymorphic_parent_class']}.reflect_on_association(:#{record['polymorphic_association_id']})"

          # rewrite the record with the right column names
          table_aliases = reflection.options[:table_aliases].dup
          record = Hash[*table_aliases.keys.map {|key| [key, record[table_aliases[key]]] }.flatten]          
          
          # find the real child class
          klass = record["#{self.table_name}.#{reflection.options[:polymorphic_type_key]}"].constantize
          if sti_klass = record["#{klass.table_name}.#{klass.inheritance_column}"]
            klass = klass.class_eval do compute_type(sti_klass) end # in case of namespaced STI models
          end
          
          # check that the join actually joined to something
          unless (child_id = record["#{self.table_name}.#{reflection.options[:polymorphic_key]}"]) == record["#{klass.table_name}.#{klass.primary_key}"]
            raise ActiveRecord::Associations::PolymorphicError, 
              "Referential integrity violation; child <#{klass.name}:#{child_id}> was not found for #{reflection.name.inspect}" 
          end
          
          # eject the join keys
          # XXX not very readable
          record = Hash[*record._select do |column, value| 
            column[/^#{klass.table_name}/]
          end.map do |column, value|
            [column[/\.(.*)/, 1], value]
          end.flatten]
                    
          # allocate and assign values
          returning(klass.allocate) do |obj|
            obj.instance_variable_set("@attributes", record)
            obj.instance_variable_set("@attributes_cache", Hash.new)
            
            if obj.respond_to_without_attributes?(:after_find)
              obj.send(:callback, :after_find)
            end
            
            if obj.respond_to_without_attributes?(:after_initialize)
              obj.send(:callback, :after_initialize)
            end
            
          end
        else                       
          instantiate_without_polymorphic_checks(record)
        end
      end
      
      alias_method_chain :instantiate, :polymorphic_checks 
    end
    
  end
end
