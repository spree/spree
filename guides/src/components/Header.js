import * as React from 'react'
import { Link } from 'gatsby'

import Logo from './Logo'
import NavItem from './NavItem'

const Header = () => (
  <header className="bb b--near-white">
    <div className="mw9 center pa3 flex items-center justify-between">
      <Link to="/" className="link green">
        <Logo />
      </Link>

      <nav>
        <NavItem url="/api">Api</NavItem>
        <NavItem url="/developer">Developer</NavItem>
        <NavItem url="/user">User</NavItem>
        <NavItem url="/release_notes">Release-notes</NavItem>
        <NavItem url="http://slack.spreecommerce.org/">Slack</NavItem>
        <NavItem url="https://heroku.com/deploy?template=https://github.com/spree/spree">
          Demo
        </NavItem>
      </nav>
    </div>
  </header>
)

export default Header
