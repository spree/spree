module ActionController #:nodoc:
  class TestResponse #:nodoc:
    attr_writer :controller_path

    def capture(name)
      template.instance_variable_get "@content_for_#{name.to_s}"
    end
    
    if ::Rails::VERSION::STRING < "2.3"
      def [](name)
        Kernel.warn <<-WARNING
[](name) as an alias for capture(name) (TestResponse extension in rspec-rails)
is deprecated and will be removed in the rspec-rails release that follows the
rails-2.3.0 release.
WARNING
        capture(name)
      end
    end
  end
end
