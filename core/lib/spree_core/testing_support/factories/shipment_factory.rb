Factory.define :shipment do |f|
  f.order { Factory(:order) }
  f.shipping_method { Factory(:shipping_method) }
  f.tracking 'U10000'
  f.number "100"
  f.cost 100.00
  f.address { Factory(:address) }
  f.state "pending"
end

  #create_table "shipments", :force => true do |t|
    #t.integer  "order_id"
    #t.integer  "shipping_method_id"
    #t.string   "tracking"
    #t.datetime "created_at"
    #t.datetime "updated_at"
    #t.string   "number"
    #t.decimal  "cost",               :precision => 8, :scale => 2
    #t.datetime "shipped_at"
    #t.integer  "address_id"
    #t.string   "state"
  #end
