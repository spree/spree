Order.class_eval do
  def self.find_by_param(param)
    Order.where("id = ? OR number = ?", param, param).first
  end
end
