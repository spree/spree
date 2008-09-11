class PaymentPresenter < ActivePresenter::Base
  #presents :credit_card, :address
  presents :creditcard, :address
end