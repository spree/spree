Spree::Payment.class_eval do
  def authorize!
    self.payment_source.authorize(self)
  end
end
