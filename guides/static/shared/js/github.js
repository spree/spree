$(function(){

  // Get last commits to API folder
  $.ajax({
    
    url: "https://api.github.com/repos/spree/spree/commits?path=api", 
    dataType: "jsonp",
    
    success: function(data){
      $.each(data.data, function(index, item){
        if(index < 5) {          
          $("#commits").append(
                               "<li class='commit'><i class='icon-dot'></i>" +
                                "<a class='commit-message' href='https://github.com/spree/spree/commit/" + item.sha + "' target='_blank'>" + item.commit.message.replace(/\n/g, "<br />") + "</a>" + 
                                "<div class='info'>"+
                                  "<span class='commit-date'>" + item.commit.committer.date + "</span>" +
                                  "<span class='commit-author'><a href='https://github.com/" + item.author.login + "'>@" + item.author.login + "</a></span>" +
                                "</div>" +
                               "</li>"
                               );
          $('.commit-message').trunk8({
            lines: 1,
            fill: '&hellip;'
          });
        }
      });

    }
  });

});