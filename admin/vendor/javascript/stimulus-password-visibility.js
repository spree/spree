// stimulus-password-visibility@2.1.1 downloaded from https://ga.jspm.io/npm:stimulus-password-visibility@2.1.1/dist/stimulus-password-visibility.mjs

import{Controller as t}from"@hotwired/stimulus";class s extends t{connect(){this.hidden="password"===this.inputTarget.type,this.class=this.hasHiddenClass?this.hiddenClass:"hidden"}toggle(t){t.preventDefault(),this.inputTarget.type=this.hidden?"text":"password",this.hidden=!this.hidden,this.iconTargets.forEach((t=>t.classList.toggle(this.class)))}}s.targets=["input","icon"];s.classes=["hidden"];export{s as default};

