Factory.define :prototype do |f|
  f.name "Baseball Cap"
  f.properties { [ Factory(:property) ]}
end
