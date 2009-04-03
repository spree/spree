class ShipmentPresenter < ActivePresenter::Base
  presents :shipment, :address
end