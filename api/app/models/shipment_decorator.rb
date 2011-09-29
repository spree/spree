Shipment.class_eval do
  def self.find_by_param(param)
    if param.to_i > 0
      Shipment.find(param)
    else
      Shipment.where(:number => param).first
    end
  end
end
