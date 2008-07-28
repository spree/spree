module Spec
  module Rails
    module Example
      # Model examples live in $RAILS_ROOT/spec/models/.
      #
      # Model examples use Spec::Rails::Example::ModelExampleGroup, which
      # provides support for fixtures and some custom expectations via extensions
      # to ActiveRecord::Base.
      class ModelExampleGroup < RailsExampleGroup
        Spec::Example::ExampleGroupFactory.register(:model, self)
      end
    end
  end
end
