module ExplicitHelper
  def method_in_explicit_helper
    "<div>This is text from a method in the ExplicitHelper</div>"
  end
  
  # this is an example of a method spec'able with eval_erb in helper specs
  def prepend(arg, &block)
    concat(arg, block.binding) + block.call
  end
end
