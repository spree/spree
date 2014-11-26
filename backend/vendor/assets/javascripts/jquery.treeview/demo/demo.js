$(document).ready(function(){
		
	// first example
	$("#navigation").treeview({
		collapsed: true,
		unique: true,
		persist: "location"
	});

	
	// second example
	$("#browser").treeview({
		animated:"normal",
		persist: "cookie"
	});

	$("#samplebutton").click(function(){
		var branches = $("<li><span class='folder'>New Sublist</span><ul>" + 
			"<li><span class='file'>Item1</span></li>" + 
			"<li><span class='file'>Item2</span></li></ul></li>").appendTo("#browser");
		$("#browser").treeview({
			add: branches
		});
	});


	// third example
	$("#red").treeview({
		animated: "fast",
		collapsed: true,
		control: "#treecontrol"
	});


});