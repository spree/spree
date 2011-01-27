Factory.define :adjustment do  |f|
  f.order { Factory(:order) }
  f.amount "100.0"
  f.label 'Shipping'
  f.source { Factory(:shipment) }
end
  #create_table "adjustments", :force => true do |t|
    #t.integer  "order_id"
    #t.decimal  "amount"
    #t.string   "label"
    #t.datetime "created_at"
    #t.datetime "updated_at"
    #t.integer  "source_id"
    #t.string   "source_type"
    #t.boolean  "mandatory"
    #t.boolean  "locked"
    #t.integer  "originator_id"
    #t.string   "originator_type"
  #end
