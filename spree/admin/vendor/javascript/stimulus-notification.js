// stimulus-notification@2.2.0 downloaded from https://ga.jspm.io/npm:stimulus-notification@2.2.0/dist/stimulus-notification.mjs

import{Controller as e}from"@hotwired/stimulus";import{useTransition as t}from"stimulus-use";class i extends e{initialize(){this.hide=this.hide.bind(this)}connect(){t(this),!1===this.hiddenValue&&this.show()}show(){this.enter(),this.timeout=setTimeout(this.hide,this.delayValue)}async hide(){this.timeout&&clearTimeout(this.timeout),await this.leave(),this.element.remove()}}i.values={delay:{type:Number,default:3e3},hidden:{type:Boolean,default:!1}};export{i as default};

