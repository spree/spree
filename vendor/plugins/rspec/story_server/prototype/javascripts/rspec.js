var InPlaceEditor = {};
InPlaceEditor.Local = Class.create();
Object.extend(Object.extend(InPlaceEditor.Local.prototype, Ajax.InPlaceEditor.prototype), {
  enterHover: function() {},
  leaveHover: function() {},
  onComplete: function() {},
  handleFormSubmission: function(e) {
    var value = $F(this._controls.editor);
    RSpec.addStockStep(value);    
    this.element.innerHTML = value;
    this.leaveEditMode();
    if (e) Event.stop(e);
  }
});

var RSpec = {
  stockSteps: function() {
    return $('stock_steps').childElements().map(function(li){ 
      return li.innerHTML;
    }).sort();
  },
  
  addStockStep: function(stockStep) {
    if(!this.stockSteps().include(stockStep)) {
      $('stock_steps').appendChild(Builder.node('li', {}, stockStep));
    }
  },
  
  makeParamEditors: function() {
    $$('span.param').each(function(span) {
      span.removeClassName('param');
      span.addClassName('param_editor');
      new InPlaceEditor.Local(span, null, {});
    });
  },
  
  setId: function(e) {
    if(!this.currentId) this.currentId = 0;
    this.currentId++;
    e.id = "id_" + this.currentId;
  },
  
  applyUi: function() {
    this.setUpTogglers();
    this.makeParamEditors();

    var currentId = 0;
    $$('ul.steps').each(function(ul) {
      RSpec.setId(ul);
      var footer = document.createElement("p");
      var addStepLink = document.createElement("a");
      addStepLink.href = "#";
      addStepLink.appendChild(document.createTextNode('Add step'));
      footer.appendChild(addStepLink);      
      ul.parentNode.appendChild(footer);

      Sortable.create(ul, {
        scroll: window
      });

/*    Disable for now - it messes with the autocomplete's visibility (zIndex galore)  
      Droppables.add(footer, {
        hoverclass: 'wastebin',
        onDrop: function(li, droppable, evt) {
          li.remove();
        }
      });
*/      
      Event.observe(addStepLink, 'click', function() {
        var form = Builder.node('form', {});
        
        var li = Builder.node('li', {className: 'new'});
        var input = Builder.node('input', {}, 'New step here');
        var autoComplete = Builder.node('div', {className: 'auto_complete'}, '');

        li.appendChild(form);
        form.appendChild(input);
        form.appendChild(autoComplete);
        ul.appendChild(li);
        Sortable.destroy(ul);
        Sortable.create(ul);

        Event.observe(form, 'submit', function(e) {
          var value = input.value;
          Element.remove(this);
          li.innerHTML = value.gsub(/(\$[a-z]*)/, '<span class="param">#{1}</span>');
          RSpec.makeParamEditors();
          if (e) Event.stop(e);
        });

        var ac = new Autocompleter.Local(input, autoComplete, RSpec.stockSteps(), {});
        input.focus();
      });
    })
  },
  
  setUpTogglers: function() {
    $$('dt').each(function(dt) {
      var dd = dt.parentNode.getElementsByTagName('dd')[0];
      dt.onclick = function(){
        dd.toggle();
      }
    });
  }
};

var StoryDom = {
  narrativeText: function(s) {
    return s.split(/\n/m).map(function(line){
      if(line == "" || line.match(/^\s+$/) ) {
        return null;
      } else {
        return "  " + (line.gsub(/^\s+/, '').gsub(/<br \/>/, "\n").gsub(/<br>/, "\n"));
      }
    }).compact().join("");
  },
  
  stepText: function(s) {
    return s.gsub(/<span[^>]*>([^<]*)<\/span>/, "#{1}");
  },
  
  scenario: function(dl) {
    var scenario = '  Scenario: ' + dl.getElementsByTagName('dt')[0].innerHTML + '\n';
    scenario += $A(dl.getElementsByTagName('li')).map(function(li){
      return '    ' + StoryDom.stepText(li.innerHTML);
    }).join("\n") + "\n";
    return scenario;
  },
  
  story: function() {
    var dl = $$('dl.story')[0];
    var story = 'Story: ' + dl.getElementsByTagName('dt')[0].innerHTML + '\n\n';
    story += this.narrativeText(dl.getElementsByTagName('p')[0].innerHTML) + '\n';
    story += $A(dl.getElementsByTagName('dl')).map(function(scenarioDl){
      return StoryDom.scenario(scenarioDl);
    }).join("\n");
    return story;
  },
  
  save: function() {
    new Ajax.Request('stories', {
      postBody: this.story()
    });
  }
};

Event.observe(window, 'load', function() {
  RSpec.applyUi();
});
