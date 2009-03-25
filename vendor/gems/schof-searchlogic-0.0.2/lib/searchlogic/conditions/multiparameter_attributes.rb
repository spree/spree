module Searchlogic
  module Conditions
    # = Multiparameter Attributes
    #
    # This code is largely copied over from ActiveRecord, so that we can handle the date_select and datetime_select helpers.
    # One option would be to instantiate a new ActiveRecord object, pass the attributes to it, then get the field value. This
    # would not be smart for performance because there is a lot going on there that we don't need, such as instantiating an entirely
    # new object. ActiveRecord gives us no other way to use the code, so the only other option is to copy over the methods that handle this.
    # This ultimately results in better performance.
    module MultiparameterAttributes
      def self.included(klass)
        klass.class_eval do
          alias_method_chain :conditions=, :multiparameter_attributes
        end
      end
      
      def conditions_with_multiparameter_attributes=(attributes)
        if attributes.is_a?(Hash)
          multiparameter_attributes = []
          clean_attributes = {}
          attributes.each do |k,v|
            if k.to_s.include?("(")
              multiparameter_attributes << [k, v]
            else
              clean_attributes[k] = v
            end
          end
          
          attributes = clean_attributes.merge(convert_multiparameter_attributes(multiparameter_attributes))
        end
        
        self.conditions_without_multiparameter_attributes = attributes
      end
      
      private
        def instantiate_time_object(name, values)
          if klass.respond_to?(:create_time_zone_conversion_attribute, true) && klass.send(:create_time_zone_conversion_attribute?, name, column_for_attribute(name))
            Time.zone.local(*values)
          else
            Time.time_with_datetime_fallback(klass.default_timezone, *values)
          end
        end
        
        def convert_multiparameter_attributes(pairs)
          convert_callstack_for_multiparameter_attributes(
            extract_callstack_for_multiparameter_attributes(pairs)
          )
        end
        
        def convert_callstack_for_multiparameter_attributes(callstack)
          r = {}
          callstack.each do |name, values|
            date_klass = send("#{name}_object").column_for_type_cast.klass
            if values.empty?
              r[name] = nil
            else
              begin
                value = if Time == date_klass
                  instantiate_time_object(name, values)
                elsif Date == date_klass
                  begin
                    Date.new(*values)
                  rescue ArgumentError => ex # if Date.new raises an exception on an invalid date
                    instantiate_time_object(name, values).to_date # we instantiate Time object and convert it back to a date thus using Time's logic in handling invalid dates
                  end
                else
                  date_klass.new(*values)
                end
                
                r[name] = value
              rescue => ex
                raise ArgumentError.new("error on assignment #{values.inspect} to #{name}")
              end
            end
          end
          r
        end

        def extract_callstack_for_multiparameter_attributes(pairs)
          attributes = { }

          for pair in pairs
            multiparameter_name, value = pair
            attribute_name = multiparameter_name.split("(").first
            attributes[attribute_name] = [] unless attributes.include?(attribute_name)

            unless value.empty?
              attributes[attribute_name] <<
                [ find_parameter_position(multiparameter_name), type_cast_attribute_value(multiparameter_name, value) ]
            end
          end

          attributes.each { |name, values| attributes[name] = values.sort_by{ |v| v.first }.collect { |v| v.last } }
        end
        
        def type_cast_attribute_value(multiparameter_name, value)
          multiparameter_name =~ /\([0-9]*([a-z])\)/ ? value.send("to_" + $1) : value
        end

        def find_parameter_position(multiparameter_name)
          multiparameter_name.scan(/\(([0-9]*).*\)/).first.first
        end
    end
  end
end