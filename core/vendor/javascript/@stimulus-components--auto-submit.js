// @stimulus-components/auto-submit@6.0.0 downloaded from https://ga.jspm.io/npm:@stimulus-components/auto-submit@6.0.0/dist/stimulus-auto-submit.mjs

import{Controller as t}from"@hotwired/stimulus";function debounce(t,e){let i;return(...s)=>{clearTimeout(i),i=setTimeout((()=>{t.apply(this,s)}),e)}}const e=class _AutoSubmit extends t{initialize(){this.submit=this.submit.bind(this)}connect(){this.delayValue>0&&(this.submit=debounce(this.submit,this.delayValue))}submit(){this.element.requestSubmit()}};e.values={delay:{type:Number,default:150}};let i=e;export{i as default};

