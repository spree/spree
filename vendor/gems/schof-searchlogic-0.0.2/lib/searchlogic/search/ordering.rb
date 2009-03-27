module Searchlogic
  module Search
    # = Search Ordering
    #
    # The purpose of this module is to provide easy ordering for your searches. All that these options do is
    # build :order for you. This plays a huge part in ordering your data on the interface. See the options and examples below. The readme also touches on ordering. It's pretty simple thought:
    #
    # === Examples
    #
    #   search.order_by = :id
    #   search.order_by = [:id, :first_name]
    #   search.order_by = {:user_group => :name}
    #   search.order_by = [:id, {:user_group => :name}]
    #   search.order_by = {:user_group => {:account => :name}} # you can traverse through all of your relationships
    #
    #   search.order_as = "DESC"
    #   search.order_as = "ASC"
    module Ordering
      def self.included(klass)
        klass.class_eval do
          alias_method_chain :order=, :ordering
          alias_method_chain :sanitize, :ordering
          attr_reader :priority_order
        end
      end
      
      def order_with_ordering=(value) # :nodoc
        @order_by = nil
        @order_as = nil
        @order_by_auto_joins = nil
        self.order_without_ordering = value
      end
      
      # Convenience method for determining if the ordering is ascending
      def asc?
        !desc?
      end
      
      # Convenience method for determining if the ordering is descending
      def desc?
        return false if order_as.nil?
        order_as == "DESC"
      end
      
      # Determines how the search is being ordered: as DESC or ASC
      def order_as
        return if order.blank?
        return @order_as if @order_as
        
        case order
        when /ASC$/i
          @order_as = "ASC"
        when /DESC$/i 
          @order_as = "DESC"
        else
          nil
        end
      end
      
      # Sets how the results will be ordered: ASC or DESC
      def order_as=(value)
        value = value.blank? ? nil : value.to_s.upcase
        raise(ArgumentError, "order_as only accepts a blank string / nil or a string as 'ASC' or 'DESC'") if !value.blank? && !["ASC", "DESC"].include?(value)
        if @order_by
          @order = order_by_to_order(@order_by, value)
        elsif order
          @order.gsub!(/(ASC|DESC)/i, value)
        end
        @order_as = value
      end
      
      # Determines by what columns the search is being ordered. This is nifty in that is reverse engineers the order SQL to determine this, only
      # if you haven't explicitly set the order_by option yourself.
      def order_by
        return if order.blank?
        @order_by ||= order_to_order_by(order)
      end
      
      # Lets you set how to order the data
      #
      # === Examples
      #
      # In these examples "ASC" is determined by the value of order_as
      #
      #   order_by = :id # => users.id ASC
      #   order_by = [:id, name] # => users.id ASC, user.name ASC
      #   order_by = [:id, {:user_group => :name}] # => users.id ASC, user_groups.name ASC
      def order_by=(value)  
        @order_by_auto_joins = nil
        @order_by = get_order_by_value(value)
        @order = order_by_to_order(@order_by, @order_as)
        @order_by
      end
      
      # Returns the joins neccessary for the "order" statement so that we don't get an SQL error
      def order_by_auto_joins
        @order_by_auto_joins ||= build_order_by_auto_joins(order_by)
      end
      
      # Let's you set a priority order. Meaning this will get ordered first before anything else, but is unnoticeable and abstracted out from your regular order. For example, lets say you have a model called Product
      # that had a "featured" boolean column. You want to order the products by the price, quantity, etc., but you want the featured products to always be first.
      #
      # Without a priority order your controller would get cluttered and your code would be much more complicated. All of your order_by_link methods would have to be order_by_link [:featured, :price], :text => "Price"
      # Your order_by_link methods alternate between ASC and DESC, so the featured products would jump from the top the bottom. It presents a lot of "work arounds". So priority_order solves this.
      def priority_order=(value)
        @priority_order = value
      end
      
      # Same as order_by but for your priority order. See priority_order= for more informaton on priority_order.
      def priority_order_by
        return if priority_order.blank?
        @priority_order_by ||= order_to_order_by(priority_order)
      end
      
      # Same as order_by= but for your priority order. See priority_order= for more informaton on priority_order.
      def priority_order_by=(value)
        @priority_order_by_auto_joins = nil
        @priority_order_by = get_order_by_value(value)
        @priority_order = order_by_to_order(@priority_order_by, @priority_order_as)
        @priority_order_by
      end
      
      # Same as order_as but for your priority order. See priority_order= for more informaton on priority_order.
      def priority_order_as
        return if priority_order.blank?
        return @priority_order_as if @priority_order_as
        
        case priority_order
        when /ASC$/i
          @priority_order_as = "ASC"
        when /DESC$/i 
          @priority_order_as = "DESC"
        else
          nil
        end
      end
      
      # Same as order_as= but for your priority order. See priority_order= for more informaton on priority_order.
      def priority_order_as=(value)
        value = value.blank? ? nil : value.to_s.upcase
        raise(ArgumentError, "priority_order_as only accepts a blank string / nil or a string as 'ASC' or 'DESC'") if !value.blank? && !["ASC", "DESC"].include?(value)
        if @priority_order_by
          @priority_order = order_by_to_order(@priority_order_by, value)
        elsif priority_order
          @priority_order.gsub!(/(ASC|DESC)/i, value)
        end
        @priority_order_as = value
      end
      
      def priority_order_by_auto_joins
        @priority_order_by_auto_joins ||= build_order_by_auto_joins(priority_order_by)
      end
      
      def sanitize_with_ordering(searching = true)
        find_options = sanitize_without_ordering(searching)
        unless priority_order.blank?
          order_parts = [priority_order, find_options[:order]].compact
          find_options[:order] = order_parts.join(", ")
        end
        find_options
      end
      
      private
        def order_by_to_order(order_by, order_as, alt_klass = nil)
          return if order_by.blank?
          
          k = alt_klass || klass
          table_name = k.table_name
          sql_parts = []
          
          case order_by
          when Array
            order_by.each { |part| sql_parts << order_by_to_order(part, order_as, alt_klass) }
          when Hash
            raise(ArgumentError, "when passing a hash to order_by you must only have 1 key: {:user_group => :name} not {:user_group => :name, :user_group => :id}. The latter should be [{:user_group => :name}, {:user_group => :id}]") if order_by.keys.size != 1
            key = order_by.keys.first
            reflection = k.reflect_on_association(key.to_sym)
            value = order_by.values.first
            sql_parts << order_by_to_order(value, order_as, reflection.klass)
          when Symbol, String
            part = "#{quote_table_name(table_name)}.#{quote_column_name(order_by)}"
            part += " #{order_as}" unless order_as.blank?
            sql_parts << part
          end
          
          sql_parts.join(", ")
        end
        
        def order_to_order_by(order)
          # Reversege engineer order, only go 1 level deep with relationships, anything beyond that is probably excessive and not good for performance
          order_parts = order.split(",").collect do |part|
            part.strip!
            part.gsub!(/ (ASC|DESC)$/i, "")
            part.gsub!(/(.*)\./, "")
            table_name = ($1 ? $1.gsub(/[^a-z0-9_]/i, "") : nil)
            part.gsub!(/[^a-z0-9_]/i, "")
            reflection = nil
            if table_name && table_name != klass.table_name
              reflection = klass.reflect_on_association(table_name.to_sym) || klass.reflect_on_association(table_name.singularize.to_sym)
              next unless reflection
              {reflection.name.to_s => part}
            else
              part
            end
          end.compact
          order_parts.size <= 1 ? order_parts.first : order_parts
        end
        
        def build_order_by_auto_joins(order_by_value)
          case order_by_value
          when Array
            order_by_value.collect { |value| build_order_by_auto_joins(value) }.uniq.compact
          when Hash
            key = order_by_value.keys.first
            value = order_by_value.values.first
            case value
            when Hash
              {key.to_sym => build_order_by_auto_joins(value)}
            else
              key.to_sym
            end
          else
            nil
          end
        end
        
        def get_order_by_value(value)
          Marshal.load(value.unpack("m").first) rescue value
        end
        
        def quote_column_name(column_name)
          klass_connection.quote_column_name(column_name)
        end

        def quote_table_name(table_name)
          klass_connection.quote_table_name(table_name)
        end
        
        def klass_connection
          @connection ||= klass.connection
        end
    end
  end
end