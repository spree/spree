class PaymentPresenter < ActivePresenter::Base
  presents :creditcard, :address
end