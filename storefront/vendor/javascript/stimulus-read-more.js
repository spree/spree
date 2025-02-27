// stimulus-read-more@4.1.0 downloaded from https://ga.jspm.io/npm:stimulus-read-more@4.1.0/dist/stimulus-read-more.mjs

import{Controller as e}from"@hotwired/stimulus";class s extends e{connect(){this.open=!1}toggle(e){!1===this.open?this.show(e):this.hide(e)}show(e){this.open=!0;const t=e.target;t.innerHTML=this.lessTextValue,this.contentTarget.style.setProperty("--read-more-line-clamp","'unset'")}hide(e){this.open=!1;const t=e.target;t.innerHTML=this.moreTextValue,this.contentTarget.style.removeProperty("--read-more-line-clamp")}}s.targets=["content"];s.values={moreText:String,lessText:String};export{s as default};

