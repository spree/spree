module Searchlogic
  module Conditions
    # = Magic Methods
    #
    # Handles all method magic, creating methods on the fly, etc. This is needed for modifiers.
    module MagicMethods
      def self.included(klass)
        klass.metaclass.class_eval do
          include ClassMethods
          attr_accessor :added_class_level_conditions, :added_column_equals_conditions, :added_associations
        end
        
        klass.class_eval do
          include InstanceMethods
          alias_method_chain :initialize, :magic_methods
          alias_method_chain :method_missing, :magic_methods
        end
      end
      
      module ClassMethods # :nodoc:
        def column_details
          return @column_details if @column_details
          
          @column_details = []
          
          klass.columns.each do |column|
            column_detail = {:column => column}
            column_detail[:aliases] = case column.type
            when :datetime, :time, :timestamp
              [column.name.gsub(/_at$/, "")]
            when :date
              [column.name.gsub(/_at$/, "")]
            else
              []
            end
            
            @column_details << column_detail
          end
          
          @column_details
        end
      end
      
      module InstanceMethods # :nodoc:
        def initialize_with_magic_methods(*args)
          add_associations!
          add_column_equals_conditions!
          add_class_level_conditions!
          initialize_without_magic_methods(*args)
        end
        
        private
          def add_associations!
            return true if self.class.added_associations
          
            klass.reflect_on_all_associations.each do |association|
              next if !association.options[:finder_sql].nil? # associations with finder_sql should not be added since conditions can not be chained to them, etc.
              self.class.class_eval <<-"end_eval", __FILE__, __LINE__
                def #{association.name}
                  return @#{association.name} unless @#{association.name}.nil?
                  @#{association.name} = Searchlogic::Conditions::Base.create_virtual_class(#{association.class_name}).new
                  @#{association.name}.object_name = :#{association.name}
                  @#{association.name}.protect = protect
                  objects << @#{association.name}
                  @#{association.name}
                end
            
                def #{association.name}=(conditions)
                  @conditions = nil
                  #{association.name}.conditions = conditions
                end
              
                def reset_#{association.name}!
                  objects.delete(#{association.name})
                  @#{association.name} = nil
                end
              end_eval
            end
          
            self.class.added_associations = true
          end
        
          def add_column_equals_conditions!
            return true if self.class.added_column_equals_conditions
            klass.column_names.each { |name| setup_condition(name) }
            self.class.added_column_equals_conditions = true
          end
          
          def add_class_level_conditions!
            return true if self.class.added_class_level_conditions
            class_level_conditions = self.class.conditions.select { |condition_class| !condition_class.condition_names_for_model.blank? }
            class_level_conditions.each do |condition_class|
              condition_class.condition_names_for_model.each_with_index do |condition_name, index|
                if index == 0
                  add_condition!(condition_class, condition_name, :column => klass.columns_hash[klass.primary_key])
                else
                  add_condition_alias!(condition_name, condition_class.condition_names_for_model.first)
                end
              end
            end
            self.class.added_class_level_conditions = true
          end
        
          def sanitize_method_name(name)
            name.gsub("=", "").gsub(/^(and|or)_/, "")
          end
        
          def extract_column_and_condition_from_method_name(name)
            name_parts = sanitize_method_name(name).split("_")
          
            condition_parts = []
            column = nil
            while column.nil? && name_parts.size > 0
              possible_column_name = name_parts.join("_")
            
              self.class.column_details.each do |column_detail|
                if column_detail[:column].name == possible_column_name || column_detail[:aliases].include?(possible_column_name)
                  column = column_detail
                  break
                end
              end
            
              condition_parts << name_parts.pop if !column
            end
          
            return if column.nil?
          
            condition_name = condition_parts.reverse.join("_")
            condition = nil
          
            # Find the real condition
            self.class.conditions.each do |condition_klass|
              if condition_klass.condition_names_for_column.include?(condition_name)
                condition = condition_klass
                break
              end
            end
                                         
            [column, condition]
          end
        
          def breakdown_method_name(name)
            column_detail, condition_klass = extract_column_and_condition_from_method_name(name)
            if !column_detail.nil? && !condition_klass.nil?
              # There were no modifiers
              return [[], column_detail, condition_klass]
            else
              # There might be modifiers
              name_parts = name.split("_of_")
              column_detail, condition_klass = extract_column_and_condition_from_method_name(name_parts.pop)
              if !column_detail.nil? && !condition_klass.nil?
                # There were modifiers, lets get their real names
                modifier_klasses = []
                name_parts.each do |modifier_name|
                  size_before = modifier_klasses.size
                  self.class.modifiers.each do |modifier_klass|
                    if modifier_klass.modifier_names.include?(modifier_name)
                      modifier_klasses << modifier_klass
                      break
                    end
                  end
                  return if modifier_klasses.size == size_before # there was an invalid modifer, return nil for everything and let it act as a nomethoderror
                end
              
                return [modifier_klasses, column_detail, condition_klass]
              end
            end
          
            nil
          end
        
          def build_method_name(modifier_klasses, column_name, condition_name)
            modifier_name_parts = []
            modifier_klasses.each { |modifier_klass| modifier_name_parts << modifier_klass.modifier_names.first }
            method_name_parts = []
            method_name_parts << modifier_name_parts.join("_of_") + "_of" unless modifier_name_parts.blank?
            method_name_parts << column_name
            method_name_parts << condition_name unless condition_name.blank?
            method_name_parts.join("_").underscore
          end
        
          def method_missing_with_magic_methods(name, *args, &block)
            if setup_condition(name)
              send(name, *args, &block)
            else
              method_missing_without_magic_methods(name, *args, &block)
            end
          end
        
          def setup_condition(name)
            modifier_klasses, column_detail, condition_klass = breakdown_method_name(name.to_s)
            if !column_detail.nil? && !condition_klass.nil?
              method_name = build_method_name(modifier_klasses, column_detail[:column].name, condition_klass.condition_names_for_column.first)
            
              if !added_condition?(method_name)
                column_type = column_sql = nil
                if !modifier_klasses.blank?
                  # Find the column type
                  column_type = modifier_klasses.first.return_type
                
                  # Build the column sql
                  column_sql = "{table}.{column}"
                  modifier_klasses.each do |modifier_klass|
                    next unless klass.connection.respond_to?(modifier_klass.adapter_method_name)
                    column_sql = klass.connection.send(modifier_klass.adapter_method_name, column_sql)
                  end
                end
            
                add_condition!(condition_klass, method_name, :column => column_detail[:column], :column_type => column_type, :column_sql_format => column_sql)
            
                ([column_detail[:column].name] + column_detail[:aliases]).each do |column_name|
                  condition_klass.condition_names_for_column.each do |condition_name|
                    alias_method_name = build_method_name(modifier_klasses, column_name, condition_name)
                    add_condition_alias!(alias_method_name, method_name) unless added_condition?(alias_method_name)
                  end
                end
              end
            
              alias_method_name = sanitize_method_name(name.to_s)
              add_condition_alias!(alias_method_name, method_name) unless added_condition?(alias_method_name)
            
              return true
            end
          
            false
          end
        
          def add_condition!(condition, name, options = {})
            options[:column] = options[:column].name if options[:column]
          
            self.class.class_eval <<-"end_eval", __FILE__, __LINE__
              def #{name}_object
                return @#{name} unless @#{name}.nil?
                @#{name} = #{condition.name}.new(klass, #{options.inspect})
                @#{name}.object_name = :#{name}
                objects << @#{name}
                @#{name}
              end
            
              def #{name}
                #{name}_object.value
              end
              alias_method :and_#{name}, :#{name}
              alias_method :or_#{name}, :#{name}
            
              def #{name}=(value)
                @conditions = nil
                #{name}_object.value = value
                value
              end
            
              def and_#{name}=(value)
                #{name}_object.explicit_any = false
                self.#{name} = value
              end
            
              def or_#{name}=(value)
                #{name}_object.explicit_any = true
                self.#{name} = value
              end
            
              def reset_#{name}!
                objects.delete(#{name}_object)
                @#{name} = nil
              end
            end_eval
          end
        
          def added_condition?(name)
            respond_to?("#{name}_object")
          end
        
          def add_condition_alias!(alias_name, name)
            self.class.class_eval do
              alias_method "#{alias_name}_object", "#{name}_object"
              alias_method alias_name, name
              alias_method "#{alias_name}=", "#{name}="
              alias_method "and_#{alias_name}=", "and_#{name}="
              alias_method "or_#{alias_name}=", "or_#{name}="
              alias_method "reset_#{alias_name}!", "reset_#{name}!"
            end
          end
      end
    end
  end
end