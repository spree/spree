module ActionController #:nodoc:
  class TestResponse #:nodoc:
    attr_writer :controller_path

    def capture(name)
      template.instance_variable_get "@content_for_#{name.to_s}"
    end
    alias [] capture

  end
end
