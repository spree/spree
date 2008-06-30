module Spec
  module Example
    class ExampleGroupFactory
      class << self
        def reset
          @example_group_types = nil
          default(ExampleGroup)
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
          opts = Hash === args.last ? args.last : {}
          superclass = determine_superclass(opts)
          superclass.describe(*args, &block)
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

      end
      self.reset
    end
  end
end
