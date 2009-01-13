
=begin rdoc
Access the <tt>has_many_polymorphs_options</tt> hash in your Rails::Initializer.run#after_initialize block if you need to modify the behavior of Rails::Initializer::HasManyPolymorphsAutoload.
=end

module Rails #:nodoc:
  class Configuration

    def has_many_polymorphs_options
      ::HasManyPolymorphs.options
    end
    
    def has_many_polymorphs_options=(hash)
      ::HasManyPolymorphs.options = HashWithIndifferentAccess.new(hash)
    end
    
  end  
end

