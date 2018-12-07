import * as React from 'react'
import PropTypes from 'prop-types'
import { Link } from 'gatsby'

import Logo from './Logo'
import NavItem from './NavItem'
import DocSearch from './DocSearch'

import styles from '../utils/styles'

import IconSlack from 'react-feather/dist/icons/slack'
import IconGithub from 'react-feather/dist/icons/github'
import IconBurger from 'react-feather/dist/icons/menu'
import IconBurgerClose from 'react-feather/dist/icons/x-circle'

const isActive = (activeRootSection, currentSection) => {
  return activeRootSection === currentSection
}

class Header extends React.PureComponent {
  state = {
    menuIsOpen: false
  }

  _toggleMenu = () => {
    this.setState({ menuIsOpen: !this.state.menuIsOpen })
  }

  render() {
    return (
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

          <nav className="w-100 tr dn flex-l items-center justify-end">
            <NavItem
              isActive={
                isActive(this.props.activeRootSection, 'api') ||
                isActive(this.props.activeRootSection, 'api/overview') ||
                isActive(this.props.activeRootSection, 'api/v2')
              }
              url="/api/overview/"
            >
              API
            </NavItem>
            <NavItem
              isActive={isActive(this.props.activeRootSection, 'developer')}
              url="/developer/"
            >
              Developer
            </NavItem>
            <NavItem
              isActive={isActive(this.props.activeRootSection, 'user')}
              url="/user/"
            >
              User
            </NavItem>
            <NavItem
              isActive={isActive(this.props.activeRootSection, 'release_notes')}
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

          <nav className="dn-l justify-end w-100 flex">
            <NavItem url="https://slack.spreecommerce.org/">
              <IconSlack />
            </NavItem>
            <NavItem url="https://github.com/spree/spree">
              <IconGithub />
            </NavItem>
            {this.state.menuIsOpen ? (
              <IconBurgerClose
                className="pointer dib dn-l"
                onClick={() => this._toggleMenu()}
              />
            ) : (
              <IconBurger
                className="pointer dib dn-l"
                onClick={() => this._toggleMenu()}
              />
            )}
          </nav>
        </div>

        {this.state.menuIsOpen && (
          <nav className="fixed w-100 vh-100 bg-white-90 pa4 flex flex-column">
            <NavItem
              isActive={
                isActive(this.props.activeRootSection, 'api') ||
                isActive(this.props.activeRootSection, 'api/overview') ||
                isActive(this.props.activeRootSection, 'api/v2')
              }
              url="/api/overview/"
            >
              API
            </NavItem>
            <NavItem
              isActive={isActive(this.props.activeRootSection, 'developer')}
              url="/developer/"
            >
              Developer
            </NavItem>
            <NavItem
              isActive={isActive(this.props.activeRootSection, 'user')}
              url="/user/"
            >
              User
            </NavItem>
            <NavItem
              isActive={isActive(this.props.activeRootSection, 'release_notes')}
              url="/release_notes/"
            >
              Release-notes
            </NavItem>
          </nav>
        )}
      </header>
    )
  }
}

Header.propTypes = {
  activeRootSection: PropTypes.string
}

export default Header
