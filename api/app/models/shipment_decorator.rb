Shipment.class_eval do
  def self.find_by_param(param)
    Shipment.where("id = ? OR number = ?", param, param).first
  end
end
