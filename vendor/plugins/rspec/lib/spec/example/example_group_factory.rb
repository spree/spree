module Spec
  module Example
    class ExampleGroupFactory
      module ClassMethods
        def reset
          @example_group_types = nil
          default(ExampleGroup)
        end

        def registered_or_ancestor_of_registered?(example_group_classes) # :nodoc:
          example_group_classes.each do |example_group_class|
            return false unless registered_types.any? do |registered_type|
              registered_type.ancestors.include? example_group_class
            end
          end
          return true
        end

        # Registers an example group class +klass+ with the symbol +type+. For
        # example:
        #
        #   Spec::Example::ExampleGroupFactory.register(:farm, FarmExampleGroup)
        #
        # With that you can append a hash with :type => :farm to the describe
        # method and it will load an instance of FarmExampleGroup.
        #
        #   describe Pig, :type => :farm do
        #     ...
        #
        # If you don't use the hash explicitly, <tt>describe</tt> will
        # implicitly use an instance of FarmExampleGroup for any file loaded
        # from the <tt>./spec/farm</tt> directory.
        def register(key, example_group_class)
          @example_group_types[key] = example_group_class
        end
        
        # Sets the default ExampleGroup class
        def default(example_group_class)
          old = @example_group_types
          @example_group_types = Hash.new(example_group_class)
          @example_group_types.merge!(old) if old
        end

        def get(key=nil)
          if @example_group_types.values.include?(key)
            key
          else
            @example_group_types[key]
          end
        end
        
        def create_example_group(*args, &block)
          raise ArgumentError if args.empty?
          raise ArgumentError unless block
          Spec::Example::add_spec_path_to(args)
          block = include_scope(args.last[:scope], &block)
          superclass = determine_superclass(args.last)
          superclass.describe(*args, &block)
        end
        
        def create_shared_example_group(*args, &block)
          Spec::Example::add_spec_path_to(args)
          SharedExampleGroup.register(*args, &block)
        end
        
        def include_scope(context, &block)
          if (Spec::Ruby.version.to_f == 1.9) && Module === context
            lambda {include context;instance_eval(&block)}
          else
            block
          end
        end
        
        def assign_scope(scope, args)
          args.last[:scope] = scope
        end

      protected

        def determine_superclass(opts)
          key = if opts[:type]
            opts[:type]
          elsif opts[:spec_path] =~ /spec(\\|\/)(#{@example_group_types.keys.join('|')})/
            $2 == '' ? nil : $2.to_sym
          end
          get(key)
        end
        
      private
        
        def registered_types
          @example_group_types.values
        end

      end
      extend ClassMethods
      self.reset
    end
  end
end
