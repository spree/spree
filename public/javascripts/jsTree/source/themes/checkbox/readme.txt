Attach the onchange callback to your config to make tri-state checkboxes work (from change.js)

To read the checked options just do:
  $("SELECT-YOUR-CONTAINER").find("a.checked");
  or if you used "multiple : on"
  YOUR_TREE.selected_arr