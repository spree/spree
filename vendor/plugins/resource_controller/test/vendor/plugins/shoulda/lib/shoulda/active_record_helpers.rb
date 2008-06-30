module ThoughtBot # :nodoc:
  module Shoulda # :nodoc:
    # = Macro test helpers for your active record models
    #
    # These helpers will test most of the validations and associations for your ActiveRecord models.
    #
    #   class UserTest < Test::Unit::TestCase
    #     should_require_attributes :name, :phone_number
    #     should_not_allow_values_for :phone_number, "abcd", "1234"
    #     should_allow_values_for :phone_number, "(123) 456-7890"
    #     
    #     should_protect_attributes :password
    #     
    #     should_have_one :profile
    #     should_have_many :dogs
    #     should_have_many :messes, :through => :dogs
    #     should_belong_to :lover
    #   end
    #
    # For all of these helpers, the last parameter may be a hash of options.
    #
    module ActiveRecord
      # Ensures that the model cannot be saved if one of the attributes listed is not present.
      #
      # Options:
      # * <tt>:message</tt> - value the test expects to find in <tt>errors.on(:attribute)</tt>.  
      #   Regexp or string.  Default = <tt>/blank/</tt>
      #
      # Example:
      #   should_require_attributes :name, :phone_number
      #
      def should_require_attributes(*attributes)
        message = get_options!(attributes, :message)
        message ||= /blank/
        klass = model_class
        
        attributes.each do |attribute|
          should "require #{attribute} to be set" do
            object = klass.new
            object.send("#{attribute}=", nil)
            assert !object.valid?, "#{klass.name} does not require #{attribute}."
            assert object.errors.on(attribute), "#{klass.name} does not require #{attribute}."
            assert_contains(object.errors.on(attribute), message)
          end
        end
      end

      # Ensures that the model cannot be saved if one of the attributes listed is not unique.
      # Requires an existing record
      #
      # Options:
      # * <tt>:message</tt> - value the test expects to find in <tt>errors.on(:attribute)</tt>.  
      #   Regexp or string.  Default = <tt>/taken/</tt>
      #
      # Example:
      #   should_require_unique_attributes :keyword, :username
      #
      def should_require_unique_attributes(*attributes)
        message, scope = get_options!(attributes, :message, :scoped_to)
        message ||= /taken/
        
        klass = model_class
        attributes.each do |attribute|
          attribute = attribute.to_sym
          should "require unique value for #{attribute}#{" scoped to #{scope}" if scope}" do
            assert existing = klass.find(:first), "Can't find first #{klass}"
            object = klass.new
            
            object.send(:"#{attribute}=", existing.send(attribute))
            if scope
              assert_respond_to object, :"#{scope}=", "#{klass.name} doesn't seem to have a #{scope} attribute."
              object.send(:"#{scope}=", existing.send(scope))
            end
            
            assert !object.valid?, "#{klass.name} does not require a unique value for #{attribute}."
            assert object.errors.on(attribute), "#{klass.name} does not require a unique value for #{attribute}."
            
            assert_contains(object.errors.on(attribute), message)
            
            # Now test that the object is valid when changing the scoped attribute
            # TODO:  There is a chance that we could change the scoped field
            # to a value that's already taken.  An alternative implementation
            # could actually find all values for scope and create a unique
            # one.  
            if scope
              # Assume the scope is a foreign key if the field is nil
              object.send(:"#{scope}=", existing.send(scope).nil? ? 1 : existing.send(scope).next)
              object.errors.clear
              object.valid?
              assert_does_not_contain(object.errors.on(attribute), message, 
                                      "after :#{scope} set to #{object.send(scope.to_sym)}")
            end
          end
        end
      end

      # Ensures that the attribute cannot be set on mass update.
      # Requires an existing record.
      #
      #   should_protect_attributes :password, :admin_flag
      #
      def should_protect_attributes(*attributes)
        get_options!(attributes)
        klass = model_class

        attributes.each do |attribute|
          attribute = attribute.to_sym
          should "protect #{attribute} from mass updates" do
            protected = klass.protected_attributes || []
            accessible = klass.accessible_attributes || []

            assert protected.include?(attribute.to_s) || !accessible.include?(attribute.to_s),
                   (accessible.empty? ?
                     "#{klass} is protecting #{protected.to_a.to_sentence}, but not #{attribute}." :
                     "#{klass} has made #{attribute} accessible")
          end
        end
      end
  
      # Ensures that the attribute cannot be set to the given values
      # Requires an existing record
      #
      # Options:
      # * <tt>:message</tt> - value the test expects to find in <tt>errors.on(:attribute)</tt>.  
      #   Regexp or string.  Default = <tt>/invalid/</tt>
      #
      # Example:
      #   should_not_allow_values_for :isbn, "bad 1", "bad 2"
      #
      def should_not_allow_values_for(attribute, *bad_values)
        message = get_options!(bad_values, :message)
        message ||= /invalid/
        klass = model_class
        bad_values.each do |v|
          should "not allow #{attribute} to be set to #{v.inspect}" do
            assert object = klass.find(:first), "Can't find first #{klass}"
            object.send("#{attribute}=", v)
            assert !object.save, "Saved #{klass} with #{attribute} set to \"#{v}\""
            assert object.errors.on(attribute), "There are no errors set on #{attribute} after being set to \"#{v}\""
            assert_contains(object.errors.on(attribute), message, "when set to \"#{v}\"")
          end
        end
      end
  
      # Ensures that the attribute can be set to the given values.
      # Requires an existing record
      #
      # Example:
      #   should_allow_values_for :isbn, "isbn 1 2345 6789 0", "ISBN 1-2345-6789-0"
      #
      def should_allow_values_for(attribute, *good_values)
        get_options!(good_values)
        klass = model_class
        good_values.each do |v|
          should "allow #{attribute} to be set to #{v.inspect}" do
            assert object = klass.find(:first), "Can't find first #{klass}"
            object.send("#{attribute}=", v)
            object.save
            assert_nil object.errors.on(attribute)
          end
        end
      end

      # Ensures that the length of the attribute is in the given range
      # Requires an existing record
      #
      # Options:
      # * <tt>:short_message</tt> - value the test expects to find in <tt>errors.on(:attribute)</tt>.  
      #   Regexp or string.  Default = <tt>/short/</tt>
      # * <tt>:long_message</tt> - value the test expects to find in <tt>errors.on(:attribute)</tt>.  
      #   Regexp or string.  Default = <tt>/long/</tt>
      #
      # Example:
      #   should_ensure_length_in_range :password, (6..20)
      #
      def should_ensure_length_in_range(attribute, range, opts = {})
        short_message, long_message = get_options!([opts], :short_message, :long_message)
        short_message ||= /short/
        long_message  ||= /long/
        
        klass = model_class
        min_length = range.first
        max_length = range.last
        same_length = (min_length == max_length)

        if min_length > 0
          should "not allow #{attribute} to be less than #{min_length} chars long" do
            min_value = "x" * (min_length - 1)
            assert object = klass.find(:first), "Can't find first #{klass}"
            object.send("#{attribute}=", min_value)
            assert !object.save, "Saved #{klass} with #{attribute} set to \"#{min_value}\""
            assert object.errors.on(attribute), 
                   "There are no errors set on #{attribute} after being set to \"#{min_value}\""
            assert_contains(object.errors.on(attribute), short_message, "when set to \"#{min_value}\"")
          end
        end

        if min_length > 0
          should "allow #{attribute} to be exactly #{min_length} chars long" do
            min_value = "x" * min_length
            assert object = klass.find(:first), "Can't find first #{klass}"
            object.send("#{attribute}=", min_value)
            object.save
            assert_does_not_contain(object.errors.on(attribute), short_message, "when set to \"#{min_value}\"")
          end
        end
    
        should "not allow #{attribute} to be more than #{max_length} chars long" do
          max_value = "x" * (max_length + 1)
          assert object = klass.find(:first), "Can't find first #{klass}"
          object.send("#{attribute}=", max_value)
          assert !object.save, "Saved #{klass} with #{attribute} set to \"#{max_value}\""
          assert object.errors.on(attribute), 
                 "There are no errors set on #{attribute} after being set to \"#{max_value}\""
          assert_contains(object.errors.on(attribute), long_message, "when set to \"#{max_value}\"")
        end

        unless same_length
          should "allow #{attribute} to be exactly #{max_length} chars long" do
            max_value = "x" * max_length
            assert object = klass.find(:first), "Can't find first #{klass}"
            object.send("#{attribute}=", max_value)
            object.save
            assert_does_not_contain(object.errors.on(attribute), long_message, "when set to \"#{max_value}\"")
          end
        end
      end  
      
     # Ensures that the length of the attribute is at least a certain length
     # Requires an existing record
     #
     # Options:
     # * <tt>:short_message</tt> - value the test expects to find in <tt>errors.on(:attribute)</tt>.  
     #   Regexp or string.  Default = <tt>/short/</tt>
     #
     # Example:
     #   should_ensure_length_at_least :name, 3
     #
     def should_ensure_length_at_least(attribute, min_length, opts = {})
        short_message = get_options!([opts], :short_message)
        short_message ||= /short/
     
        klass = model_class
     
        if min_length > 0
          min_value = "x" * (min_length - 1)
          should "not allow #{attribute} to be less than #{min_length} chars long" do
            assert object = klass.find(:first), "Can't find first #{klass}"
            object.send("#{attribute}=", min_value)
            assert !object.save, "Saved #{klass} with #{attribute} set to \"#{min_value}\""
            assert object.errors.on(attribute), "There are no errors set on #{attribute} after being set to \"#{min_value}\""
            assert_contains(object.errors.on(attribute), short_message, "when set to \"#{min_value}\"")
          end
        end
        should "allow #{attribute} to be at least #{min_length} chars long" do
          valid_value = "x" * (min_length)
          assert object = klass.find(:first), "Can't find first #{klass}"
          object.send("#{attribute}=", valid_value)
          assert object.save, "Could not save #{klass} with #{attribute} set to \"#{valid_value}\""
        end
      end

      # Ensure that the attribute is in the range specified
      # Requires an existing record
      #
      # Options:
      # * <tt>:low_message</tt> - value the test expects to find in <tt>errors.on(:attribute)</tt>.  
      #   Regexp or string.  Default = <tt>/included/</tt>
      # * <tt>:high_message</tt> - value the test expects to find in <tt>errors.on(:attribute)</tt>.  
      #   Regexp or string.  Default = <tt>/included/</tt>
      #
      # Example:
      #   should_ensure_value_in_range :age, (0..100)
      #
      def should_ensure_value_in_range(attribute, range, opts = {})
        low_message, high_message = get_options!([opts], :low_message, :high_message)
        low_message  ||= /included/
        high_message ||= /included/
        
        klass = model_class
        min   = range.first
        max   = range.last

        should "not allow #{attribute} to be less than #{min}" do
          v = min - 1
          assert object = klass.find(:first), "Can't find first #{klass}"
          object.send("#{attribute}=", v)
          assert !object.save, "Saved #{klass} with #{attribute} set to \"#{v}\""
          assert object.errors.on(attribute), "There are no errors set on #{attribute} after being set to \"#{v}\""
          assert_contains(object.errors.on(attribute), low_message, "when set to \"#{v}\"")
        end

        should "allow #{attribute} to be #{min}" do
          v = min
          assert object = klass.find(:first), "Can't find first #{klass}"
          object.send("#{attribute}=", v)
          object.save
          assert_does_not_contain(object.errors.on(attribute), low_message, "when set to \"#{v}\"")
        end

        should "not allow #{attribute} to be more than #{max}" do
          v = max + 1
          assert object = klass.find(:first), "Can't find first #{klass}"
          object.send("#{attribute}=", v)
          assert !object.save, "Saved #{klass} with #{attribute} set to \"#{v}\""
          assert object.errors.on(attribute), "There are no errors set on #{attribute} after being set to \"#{v}\""
          assert_contains(object.errors.on(attribute), high_message, "when set to \"#{v}\"")
        end

        should "allow #{attribute} to be #{max}" do
          v = max
          assert object = klass.find(:first), "Can't find first #{klass}"
          object.send("#{attribute}=", v)
          object.save
          assert_does_not_contain(object.errors.on(attribute), high_message, "when set to \"#{v}\"")
        end
      end    
      
      # Ensure that the attribute is numeric
      # Requires an existing record
      #
      # Options:
      # * <tt>:message</tt> - value the test expects to find in <tt>errors.on(:attribute)</tt>.  
      #   Regexp or string.  Default = <tt>/number/</tt>
      #
      # Example:
      #   should_only_allow_numeric_values_for :age
      #
      def should_only_allow_numeric_values_for(*attributes)
        message = get_options!(attributes, :message)
        message ||= /number/
        klass = model_class
        attributes.each do |attribute|
          attribute = attribute.to_sym
          should "only allow numeric values for #{attribute}" do
            assert object = klass.find(:first), "Can't find first #{klass}"
            object.send(:"#{attribute}=", "abcd")
            assert !object.valid?, "Instance is still valid"
            assert_contains(object.errors.on(attribute), message)
          end
        end
      end

      # Ensures that the has_many relationship exists.  Will also test that the
      # associated table has the required columns.  Works with polymorphic
      # associations.
      # 
      # Options:
      # * <tt>:through</tt> - association name for <tt>has_many :through</tt>
      #
      # Example:
      #   should_have_many :friends
      #   should_have_many :enemies, :through => :friends
      #
      def should_have_many(*associations)
        through = get_options!(associations, :through)
        klass = model_class
        associations.each do |association|
          name = "have many #{association}"
          name += " through #{through}" if through
          should name do
            reflection = klass.reflect_on_association(association)
            assert reflection, "#{klass.name} does not have any relationship to #{association}"
            assert_equal :has_many, reflection.macro

            if through
              through_reflection = klass.reflect_on_association(through)
              assert through_reflection, "#{klass.name} does not have any relationship to #{through}"
              assert_equal(through, reflection.options[:through])
            end
            
            unless reflection.options[:through]
              # This is not a through association, so check for the existence of the foreign key on the other table
              if reflection.options[:foreign_key]
                fk = reflection.options[:foreign_key]
              elsif reflection.options[:as]
                fk = reflection.options[:as].to_s.foreign_key
              else
                fk = reflection.primary_key_name
              end
              associated_klass = (reflection.options[:class_name] || association.to_s.classify).constantize
              assert associated_klass.column_names.include?(fk.to_s), "#{associated_klass.name} does not have a #{fk} foreign key."
            end
          end
        end
      end

      # Ensure that the has_one relationship exists.  Will also test that the
      # associated table has the required columns.  Works with polymorphic
      # associations.
      #
      # Example:
      #   should_have_one :god # unless hindu
      #
      def should_have_one(*associations)
        get_options!(associations)
        klass = model_class
        associations.each do |association|
          should "have one #{association}" do
            reflection = klass.reflect_on_association(association)
            assert reflection, "#{klass.name} does not have any relationship to #{association}"
            assert_equal :has_one, reflection.macro
            
            associated_klass = (reflection.options[:class_name] || association.to_s.camelize).constantize

            if reflection.options[:foreign_key]
              fk = reflection.options[:foreign_key]
            elsif reflection.options[:as]
              fk = reflection.options[:as].to_s.foreign_key
              fk_type = fk.gsub(/_id$/, '_type')
              assert associated_klass.column_names.include?(fk_type), 
                     "#{associated_klass.name} does not have a #{fk_type} column."            
            else
              fk = klass.name.foreign_key
            end
            assert associated_klass.column_names.include?(fk.to_s), 
                   "#{associated_klass.name} does not have a #{fk} foreign key."            
          end
        end
      end
  
      # Ensures that the has_and_belongs_to_many relationship exists, and that the join
      # table is in place.
      #
      #   should_have_and_belong_to_many :posts, :cars
      #
      def should_have_and_belong_to_many(*associations)
        get_options!(associations)
        klass = model_class

        associations.each do |association|
          should "should have and belong to many #{association}" do
            reflection = klass.reflect_on_association(association)
            assert reflection, "#{klass.name} does not have any relationship to #{association}"
            assert_equal :has_and_belongs_to_many, reflection.macro
            table = reflection.options[:join_table]
            assert ::ActiveRecord::Base.connection.tables.include?(table), "table #{table} doesn't exist"
          end
        end
      end
  
      # Ensure that the belongs_to relationship exists.
      #
      #   should_belong_to :parent
      #
      def should_belong_to(*associations)
        get_options!(associations)
        klass = model_class
        associations.each do |association|
          should "belong_to #{association}" do
            reflection = klass.reflect_on_association(association)
            assert reflection, "#{klass.name} does not have any relationship to #{association}"
            assert_equal :belongs_to, reflection.macro

            unless reflection.options[:polymorphic]
              associated_klass = (reflection.options[:class_name] || association.to_s.classify).constantize
              fk = reflection.options[:foreign_key] || reflection.primary_key_name
              assert klass.column_names.include?(fk.to_s), "#{klass.name} does not have a #{fk} foreign key."
            end
          end
        end
      end
      
      # Ensure that the given class methods are defined on the model.
      #
      #   should_have_class_methods :find, :destroy
      #
      def should_have_class_methods(*methods)
        get_options!(methods)
        klass = model_class
        methods.each do |method|
          should "respond to class method ##{method}" do
            assert_respond_to klass, method, "#{klass.name} does not have class method #{method}"
          end
        end
      end

      # Ensure that the given instance methods are defined on the model.
      #
      #   should_have_instance_methods :email, :name, :name=
      #
      def should_have_instance_methods(*methods)
        get_options!(methods)
        klass = model_class
        methods.each do |method|
          should "respond to instance method ##{method}" do
            assert_respond_to klass.new, method, "#{klass.name} does not have instance method #{method}"
          end
        end
      end

      # Ensure that the given columns are defined on the models backing SQL table.
      #
      #   should_have_db_columns :id, :email, :name, :created_at
      #
      def should_have_db_columns(*columns)
        column_type = get_options!(columns, :type)
        klass = model_class
        columns.each do |name|
          test_name = "have column #{name}"
          test_name += " of type #{column_type}" if column_type
          should test_name do
            column = klass.columns.detect {|c| c.name == name.to_s }
            assert column, "#{klass.name} does not have column #{name}"
          end
        end
      end

      # Ensure that the given column is defined on the models backing SQL table.  The options are the same as
      # the instance variables defined on the column definition:  :precision, :limit, :default, :null, 
      # :primary, :type, :scale, and :sql_type.
      #
      #   should_have_db_column :email, :type => "string", :default => nil,   :precision => nil, :limit    => 255, 
      #                                 :null => true,     :primary => false, :scale     => nil, :sql_type => 'varchar(255)'
      #
      def should_have_db_column(name, opts = {})
        klass = model_class
        test_name = "have column named :#{name}"
        test_name += " with options " + opts.inspect unless opts.empty?
        should test_name do
          column = klass.columns.detect {|c| c.name == name.to_s }
          assert column, "#{klass.name} does not have column #{name}"
          opts.each do |k, v|
            assert_equal column.instance_variable_get("@#{k}").to_s, v.to_s, ":#{name} column on table for #{klass} does not match option :#{k}"
          end
        end
      end

      # Ensures that there are DB indices on the given columns or tuples of columns.
      # Also aliased to should_have_index for readability
      #   
      #   should_have_indices :email, :name, [:commentable_type, :commentable_id]
      #   should_have_index :age
      #
      def should_have_indices(*columns)
        table = model_class.name.tableize
        indices = ::ActiveRecord::Base.connection.indexes(table).map(&:columns)

        columns.each do |column|
          should "have index on #{table} for #{column.inspect}" do
            columns = [column].flatten.map(&:to_s)
            assert_contains(indices, columns)
          end
        end
      end

      alias_method :should_have_index, :should_have_indices
      
      # Ensures that the model cannot be saved if one of the attributes listed is not accepted.
      #
      # Options:
      # * <tt>:message</tt> - value the test expects to find in <tt>errors.on(:attribute)</tt>.  
      #   Regexp or string.  Default = <tt>/must be accepted/</tt>
      #
      # Example:
      #   should_require_acceptance_of :eula
      #
      def should_require_acceptance_of(*attributes)
        message = get_options!(attributes, :message)
        message ||= /must be accepted/
        klass = model_class
    
        attributes.each do |attribute|
          should "require #{attribute} to be accepted" do
            object = klass.new
            object.send("#{attribute}=", false)

            assert !object.valid?, "#{klass.name} does not require acceptance of #{attribute}."
            assert object.errors.on(attribute), "#{klass.name} does not require acceptance of #{attribute}."
            assert_contains(object.errors.on(attribute), message)
          end
        end
      end
      
      private
      
      include ThoughtBot::Shoulda::Private
    end
  end
end
