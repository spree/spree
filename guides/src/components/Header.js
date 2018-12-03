import * as React from 'react'
import PropTypes from 'prop-types'
import { Link } from 'gatsby'

import Logo from './Logo'
import NavItem from './NavItem'
import DocSearch from './DocSearch'

import styles from '../utils/styles'

import IconSlack from 'react-feather/dist/icons/slack'
import IconGithub from 'react-feather/dist/icons/github'

const isActive = (activeRootSection, currentSection) => {
  return activeRootSection === currentSection
}

const Header = ({ activeRootSection }) => (
  <header
    className="bb b--light-gray fixed w-100 top-0 bg-white z-999"
    css={{
      height: styles.header.height
    }}
  >
    <div className="ph4 flex items-center w-100 h-100">
      <Link to="/" className="link db">
        <Logo />
      </Link>

      <DocSearch />

      <nav className="w-100 tr flex items-center justify-end">
        <NavItem
          isActive={
            isActive(activeRootSection, 'api') ||
            isActive(activeRootSection, 'api/overview') ||
            isActive(activeRootSection, 'api/v2')
          }
          url="/api/overview/"
        >
          API
        </NavItem>
        <NavItem
          isActive={isActive(activeRootSection, 'developer')}
          url="/developer/"
        >
          Developer
        </NavItem>
        <NavItem isActive={isActive(activeRootSection, 'user')} url="/user/">
          User
        </NavItem>
        <NavItem
          isActive={isActive(activeRootSection, 'release_notes')}
          url="/release_notes/"
        >
          Release-notes
        </NavItem>
        <NavItem url="https://heroku.com/deploy?template=https://github.com/spree/spree">
          Demo
        </NavItem>
        <NavItem url="https://slack.spreecommerce.org/">
          <IconSlack />
        </NavItem>
        <NavItem url="https://github.com/spree/spree">
          <IconGithub />
        </NavItem>
      </nav>
    </div>
  </header>
)

Header.propTypes = {
  activeRootSection: PropTypes.string
}

export default Header
