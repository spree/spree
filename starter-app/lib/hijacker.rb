# Hijacker class
#
# This class is used by RoleRequirementTestHelper to temporarily hijack a controller action for testing
#
# It can be used for other tests as well.
#
# You can contract the author with questions
#   Tim C. Harper - irb(main):001:0> ( 'tim_see_harperATgmail._see_om'.gsub('_see_', 'c').gsub('AT', '@') )
#
#
# Example usage:
#   hijacker = Hijacker.new(ListingsController)
#   hijacker.hijack_instance_method("index", "render :text => 'hello world!'" )
#   get :index        # will return "hello world"
#   hijacker.restore  # put things back the way you found it

class Hijacker
  def initialize(klass)
    @target_klass = klass
    @method_stores = {}
  end
  
  def hijack_class_method(method_name, eval_string = nil, arg_names = [], &block)
    hijack_method(class_self_instance, method_name, eval_string, arg_names, &block )
  end
  
  def hijack_instance_method(method_name, eval_string = nil, arg_names = [], &block)
    hijack_method(@target_klass, method_name, eval_string, arg_names, &block )
  end
  
  # restore all 
  def restore
    @method_stores.each_pair{|klass, method_stores|
      method_stores.reverse_each{ |method_name, method| 
        klass.send :undef_method, method_name
        klass.send :define_method, method_name, method if method
      }
    }
    @method_stores.clear
    true
  rescue
    false
  end
  
protected  

  def class_self_instance
    @target_klass.send :eval, "class << self; self; end;"
  end
  
  def hijack_method(klass, method_name, eval_string = nil, arg_names = [], &block)
    method_name = method_name.to_s
    # You have got love ruby!  What other language allows you to pillage and plunder a class like this? 
    
    (@method_stores[klass]||=[]) << [
      method_name, 
      klass.instance_methods.include?(method_name) && klass.instance_method(method_name)
    ]
    
    klass.send :undef_method, method_name
    if Symbol === eval_string
      klass.send :define_method, method_name, klass.instance_methods(eval_string)
    elsif String === eval_string
      klass.class_eval <<-EOF 
        def #{method_name}(#{arg_names * ','})
          #{eval_string}
        end
      EOF
    elsif block_given?
      klass.send :define_method, method_name, block
    end
    
    true
  rescue
    false
  end
  
end