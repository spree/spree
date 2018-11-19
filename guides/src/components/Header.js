import * as React from 'react'
import PropTypes from 'prop-types'
import { Link } from 'gatsby'

import Logo from './Logo'
import NavItem from './NavItem'
import DocSearch from './DocSearch'

const isActive = (activeRootSection, currentSection) => {
  return activeRootSection === currentSection
}

const Header = ({ activeRootSection }) => (
  <header className="bb b--moon-gray">
    <div className="mw9 center pa3 flex items-center w-100">
      <Link to="/" className="link green db">
        <Logo />
      </Link>

      <DocSearch />

      <nav className="w-100 tr">
        <NavItem isActive={isActive(activeRootSection, 'api')} url="/api.html">
          Api
        </NavItem>
        <NavItem
          isActive={isActive(activeRootSection, 'developer')}
          url="/developer.html"
        >
          Developer
        </NavItem>
        <NavItem
          isActive={isActive(activeRootSection, 'user')}
          url="/user.html"
        >
          User
        </NavItem>
        <NavItem
          isActive={isActive(activeRootSection, 'release_notes')}
          url="/release_notes.html"
        >
          Release-notes
        </NavItem>
        <NavItem url="http://slack.spreecommerce.org/">Slack</NavItem>
        <NavItem url="https://heroku.com/deploy?template=https://github.com/spree/spree">
          Demo
        </NavItem>
      </nav>
    </div>
  </header>
)

Header.propTypes = {
  activeRootSection: PropTypes.bool
}

export default Header
