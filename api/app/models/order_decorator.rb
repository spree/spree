Order.class_eval do
  def self.find_by_param(param)
    if param.to_i > 0
      Order.find(param)
    else
      Order.where(:number => param).first
    end
  end
end
