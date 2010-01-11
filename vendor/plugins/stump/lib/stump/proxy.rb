class Object
  # Creates a proxy method on an object.  In this setup, it places an expectation on an object (like a mock)
  # but still calls the original method.  So if you want to make sure the method is called and still return
  # its value, or simply want to invoke the side effects of a method and return a stubbed value, then you can
  # do that.
  #
  # ==== Examples
  #
  #     class Parrot
  #       def speak!
  #         puts @words
  #       end
  #
  #       def say_this(words)
  #         @words = words
  #         "I shall say #{words}!"
  #       end
  #     end
  #
  #     # => test/your_test.rb
  #     sqawky = Parrot.new
  #     sqawky.proxy!(:say_this)
  #     # Proxy method still calls original method...
  #     sqawky.say_this("hey")   # => "I shall say hey!"
  #     sqawky.speak!            # => "hey"
  #
  #     sqawky.proxy!(:say_this, "herro!")
  #     # Even though we return a stubbed value...
  #     sqawky.say_this("these words")   # => "herro!"
  #     # ...the side effects are still there.
  #     sqawky.speak!                    # => "these words"
  #
  # TODO: This implementation is still very rough.  Needs refactoring and refining.  Won't 
  # work on ActiveRecord attributes, for example.
  #
  def proxy!(method, options = {}, &block)
    Stump::Mocks.add([self, method])
    
    if respond_to?(method)
      proxy_existing_method(method, options, &block)
    else
      proxy_missing_method(method, options, &block)
    end
  end
  
  protected
  def proxy_existing_method(method, options = {}, &block)
    method_alias = "__old_#{method}"
    
    meta_eval do
      module_eval("alias #{method_alias} #{method}")
    end
        
    behavior = if options[:return]
                  lambda do |*args| 
                    raise ArgumentError if args.length != method(method_alias.to_sym).arity
                    
                    Stump::Mocks.verify([self, method])

                    if method(method_alias.to_sym).arity == 0
                      send(method_alias)
                    else
                      send(method_alias, *args)
                    end

                    return options[:return]
                  end
                else
                  lambda do |*args| 
                    raise ArgumentError if args.length != method(method_alias.to_sym).arity

                    Stump::Mocks.verify([self, method])
                    
                    if method(method_alias.to_sym).arity == 0
                      return send(method_alias)
                    else
                      return send(method_alias, *args)
                    end
                  end
                end

    meta_def method, &behavior
  end
  
  def proxy_missing_method(method, options = {}, &block)
    behavior = if options[:return]
                  lambda do |*args|
                    Stump::Mocks.verify([self, method])
                    
                    method_missing(method, args)
                    return options[:return]
                  end
                else
                  lambda do |*args|
                    Stump::Mocks.verify([self, method])
      
                    method_missing(method, args)
                  end
                end
    
    meta_def method, &behavior
  end
end