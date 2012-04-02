class ShippingRate < Struct.new(:id, :shipping_method, :name, :cost)
  def initialize(attributes={})
    attributes.each do |k,v|
      self.send("#{k}=", v)
    end
  end

end
