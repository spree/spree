// stimulus-reveal-controller@4.1.0 downloaded from https://ga.jspm.io/npm:stimulus-reveal-controller@4.1.0/dist/stimulus-reveal-controller.mjs

import{Controller as s}from"@hotwired/stimulus";class t extends s{connect(){this.class=this.hasHiddenClass?this.hiddenClass:"hidden"}toggle(){this.itemTargets.forEach((s=>{s.classList.toggle(this.class)}))}show(){this.itemTargets.forEach((s=>{s.classList.remove(this.class)}))}hide(){this.itemTargets.forEach((s=>{s.classList.add(this.class)}))}}t.targets=["item"];t.classes=["hidden"];export{t as default};

