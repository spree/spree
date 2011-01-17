Factory.define :shipping_method do |f|
  f.zone {|a| a.association(:zone) }
  f.name 'UPS Ground'
  f.display_on :front_end
end
