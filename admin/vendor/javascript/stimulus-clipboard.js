// stimulus-clipboard@4.0.1 downloaded from https://ga.jspm.io/npm:stimulus-clipboard@4.0.1/dist/stimulus-clipboard.mjs

import{Controller as e}from"@hotwired/stimulus";class t extends e{connect(){this.hasButtonTarget&&(this.originalContent=this.buttonTarget.innerHTML)}copy(e){e.preventDefault();const s=this.sourceTarget.innerHTML||this.sourceTarget.value;navigator.clipboard.writeText(s).then((()=>this.copied()))}copied(){this.hasButtonTarget&&(this.timeout&&clearTimeout(this.timeout),this.buttonTarget.innerHTML=this.successContentValue,this.timeout=setTimeout((()=>{this.buttonTarget.innerHTML=this.originalContent}),this.successDurationValue))}}t.targets=["button","source"];t.values={successContent:String,successDuration:{type:Number,default:2e3}};export{t as default};

