# Most of this code is from the preferences plugin available at
# http://github.com/pluginaweek/preferences/tree/master

module Spree
  module Preferences
    # Adds support for defining preferences on ActiveRecord models.
    #
    # == Saving preferences
    #
    # Preferences are not automatically saved when they are set.  You must save
    # the record that the preferences were set on.
    #
    # For example,
    #
    #   class User < ActiveRecord::Base
    #     preference :notifications
    #   end
    #
    #   u = User.new(:login => 'admin', :prefers_notifications => false)
    #   u.save!
    #
    #   u = User.find_by_login('admin')
    #   u.attributes = {:prefers_notifications => true}
    #   u.save!
    module ModelHooks
      def self.included(base) #:nodoc:
        base.class_eval do
          extend Spree::Preferences::ModelHooks::MacroMethods
        end
      end

      module MacroMethods
        # Defines a new preference for all records in the model.  By default, preferences
        # are assumed to have a boolean data type, so all values will be typecasted
        # to true/false based on ActiveRecord rules.
        #
        # Configuration options:
        # * +default+ - The default value for the preference. Default is nil.
        #
        # == Examples
        #
        # The example below shows the various ways to define a preference for a
        # particular model.
        #
        #   class User < ActiveRecord::Base
        #     preference :notifications, :default => false
        #     preference :color, :string, :default => 'red'
        #     preference :favorite_number, :integer
        #     preference :data, :any # Allows any data type to be stored
        #   end
        #
        # All preferences are also inherited by subclasses.
        #
        # == Associations
        #
        # After the first preference is defined, the following associations are
        # created for the model:
        # * +stored_preferences+ - A collection of all the custom preferences specified for a record
        #
        # == Generated shortcut methods
        #
        # In addition to calling <tt>prefers?</tt> and +preferred+ on a record, you
        # can also use the shortcut methods that are generated when a preference is
        # defined.  For example,
        #
        #   class User < ActiveRecord::Base
        #     preference :notifications
        #   end
        #
        # ...generates the following methods:
        # * <tt>prefers_notifications?</tt> - The same as calling <tt>record.prefers?(:notifications)</tt>
        # * <tt>prefers_notifications=(value)</tt> - The same as calling <tt>record.set_preference(:notifications, value)</tt>
        # * <tt>preferred_notifications</tt> - The same as called <tt>record.preferred(:notifications)</tt>
        # * <tt>preferred_notifications=(value)</tt> - The same as calling <tt>record.set_preference(:notifications, value)</tt>
        #
        # Notice that there are two tenses used depending on the context of the
        # preference.  Conventionally, <tt>prefers_notifications?</tt> is better
        # for boolean preferences, while +preferred_color+ is better for non-boolean
        # preferences.
        #
        # Example:
        #
        #   user = User.find(:first)
        #   user.prefers_notifications?         # => false
        #   user.prefers_color?                 # => true
        #   user.preferred_color                # => 'red'
        #   user.preferred_color = 'blue'       # => 'blue'
        #
        #   user.prefers_notifications = true
        #
        #   car = Car.find(:first)
        #   user.preferred_color = 'red', car   # => 'red'
        #   user.preferred_color(car)           # => 'red'
        #   user.prefers_color?(car)            # => true
        #
        #   user.save!  # => true
        def preference(name, *args)
          unless included_modules.include?(InstanceMethods)
            class_inheritable_hash :preference_definitions
            self.preference_definitions = {}

            class_inheritable_hash :default_preferences
            self.default_preferences = {}

            has_many  :stored_preferences, :as => :owner, :class_name => 'Preference'

            after_save :update_preferences

            include Spree::Preferences::ModelHooks::InstanceMethods
          end

          # Create the definition
          name = name.to_s
          definition = PreferenceDefinition.new(name, *args)
          self.preference_definitions[name] = definition
          self.default_preferences[name] = definition.default_value

          # Create short-hand helper methods, making sure that the attribute
          # is method-safe in terms of what characters are allowed
          name = name.gsub(/[^A-Za-z0-9_-]/, '').underscore

          # Query lookup
          define_method("prefers_#{name}?") do |*group|
            prefers?(name, group.first)
          end

          # Writer
          define_method("prefers_#{name}=") do |*args|
            set_preference(*([name] + [args].flatten))
          end
          alias_method "preferred_#{name}=", "prefers_#{name}="

          # Reader
          define_method("preferred_#{name}") do |*group|
            preferred(name, group.first)
          end

          definition
        end
      end

      module InstanceMethods
        def self.included(base) #:nodoc:
          base.class_eval do
            alias_method :prefs, :preferences
          end
        end

        # Finds all preferences, including defaults, for the current record.  If
        # any custom group preferences have been stored, then this will include
        # all default preferences within that particular group.
        #
        # == Examples
        #
        # A user with no stored values:
        #   user = User.find(:first)
        #   user.preferences
        #   => {"language"=>"English", "color"=>nil}
        #
        # A user with stored values for a particular group:
        #   user.preferred_color = 'red', 'cars'
        #   user.preferences
        #   => {"language"=>"English", "color"=>nil, "cars"=>{"language=>"English", "color"=>"red"}}
        #
        # Getting preference values for the owning record:
        #   user.preferences(nil)
        #   => {"language"=>"English", "color"=>nil}
        #
        # Getting preference values for a particular group:
        #   user.preferences('cars')
        #   => {"language"=>"English", "color"=>"red"}
        def preferences(*args)
          if args.empty?
            group = nil
            conditions = {}
          else
            group = args.first
            group_id, group_type = Preference.split_group(group)
            conditions = {:group_id => group_id, :group_type => group_type}
          end

          # Find all of the stored preferences
          stored_preferences = self.stored_preferences.where(conditions)

          # Hashify attribute -> value or group -> attribute -> value
          stored_preferences.inject(self.class.default_preferences.dup) do |all_preferences, preference|
            if !group && (preference_group = preference.group)
              preferences = all_preferences[preference_group] ||= self.class.default_preferences.dup
            else
              preferences = all_preferences
            end

            preferences[preference.name] = preference.value
            all_preferences
          end
        end

        # Queries whether or not a value has been specified for the given attribute.
        # This is dependent on how the value is type-casted.
        #
        # == Examples
        #
        #   user = User.find(:first)
        #   user.prefers?(:notifications)             # => true
        #
        #   user.prefers(:notifications, 'error')     # => true
        #
        #   newsgroup = Newsgroup.find(:first)
        #   user.prefers?(:notifications, newsgroup)  # => false
        def prefers?(name, group = nil)
          name = name.to_s

          value = preferred(name, group)
          preference_definitions[name].query(value)
        end

        # Gets the preferred value for the given attribute.
        #
        # == Examples
        #
        #   user = User.find(:first)
        #   user.preferred(:color)          # => 'red'
        #
        #   user.preferred(:color, 'cars')  # => 'blue'
        #
        #   car = Car.find(:first)
        #   user.preferred(:color, car)     # => 'black'
        def preferred(name, group = nil)
          name = name.to_s

          if @preference_values && @preference_values[name] && @preference_values[name].include?(group)
            value = @preference_values[name][group]
          else
            group_id, group_type = Preference.split_group(group)
            preference = stored_preferences.find(:first, :conditions => {:name => name, :group_id => group_id, :group_type => group_type})
            value = preference ? preference.value : preference_definitions[name].default_value
          end

          value
        end

        # Sets a new value for the given attribute.  The actual Preference record
        # is *not* created until the actual record is saved.
        #
        # == Examples
        #
        #   user = User.find(:first)
        #   user.set_preference(:notifications, false) # => false
        #   user.save!
        #
        #   newsgroup = Newsgroup.find(:first)
        #   user.set_preference(:notifications, true, newsgroup)  # => true
        #   user.save!
        def set_preference(name, value, group = nil)
          name = name.to_s

          @preference_values ||= {}
          @preference_values[name] ||= {}
          @preference_values[name][group] = value

          value
        end

        private

        # Updates any preferences that have been changed/added since the record
        # was last saved
        def update_preferences
          if @preference_values
            @preference_values.each do |name, grouped_records|
              grouped_records.each do |group, value|
                group_id, group_type = Preference.split_group(group)
                attributes = {:name => name, :group_id => group_id, :group_type => group_type}

                # Find an existing preference or build a new one
                preference = stored_preferences.find(:first, :conditions => attributes)
                if preference.nil?
                  attribute = attributes.delete(:attribute)
                  preference = stored_preferences.build(attributes)
                  preference['attribute'] = attribute
                end
                preference.value = value
                preference.save!
              end
            end

            @preference_values = nil
          end
        end
      end
    end
  end
end
