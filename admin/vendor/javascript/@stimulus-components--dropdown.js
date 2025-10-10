// @stimulus-components/dropdown@3.0.0 downloaded from https://ga.jspm.io/npm:@stimulus-components/dropdown@3.0.0/dist/stimulus-dropdown.mjs

import{Controller as t}from"@hotwired/stimulus";import{useTransition as e}from"stimulus-use";const s=class _Dropdown extends t{connect(){e(this,{element:this.menuTarget})}toggle(){this.toggleTransition()}hide(t){!this.element.contains(t.target)&&!this.menuTarget.classList.contains("hidden")&&this.leave()}};s.targets=["menu"];let i=s;export{i as default};

