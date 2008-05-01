module Spec
  module Example
    class ExampleGroupFactory
      class << self
        def reset
          @example_group_types = nil
          default(ExampleGroup)
        end

        # Registers an example group class +klass+ with the symbol
        # +type+. For example:
        #
        #   Spec::Example::ExampleGroupFactory.register(:farm, Spec::Farm::Example::FarmExampleGroup)
        #
        # This will cause Main#describe from a file living in 
        # <tt>spec/farm</tt> to create example group instances of type
        # Spec::Farm::Example::FarmExampleGroup.
        def register(id, example_group_class)
          @example_group_types[id] = example_group_class
        end
        
        # Sets the default ExampleGroup class
        def default(example_group_class)
          old = @example_group_types
          @example_group_types = Hash.new(example_group_class)
          @example_group_types.merge(old) if old
        end

        def get(id=nil)
          if @example_group_types.values.include?(id)
            id
          else
            @example_group_types[id]
          end
        end
        
        def create_example_group(*args, &block)
          opts = Hash === args.last ? args.last : {}
          if opts[:shared]
            SharedExampleGroup.new(*args, &block)
          else
            superclass = determine_superclass(opts)
            superclass.describe(*args, &block)
          end
        end

        protected

        def determine_superclass(opts)
          id = if opts[:type]
            opts[:type]
          elsif opts[:spec_path] =~ /spec(\\|\/)(#{@example_group_types.keys.join('|')})/
            $2 == '' ? nil : $2.to_sym
          end
          get(id)
        end

      end
      self.reset
    end
  end
end
