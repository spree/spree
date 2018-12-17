import * as React from 'react'
import PropTypes from 'prop-types'
import { Link } from 'gatsby'
import {
  join,
  juxt,
  compose,
  toUpper,
  head,
  tail,
  equals,
  or,
  length,
  filter
} from 'ramda'
import startCase from 'lodash.startcase'
import { cx } from 'emotion'

import style from '../utils/styles'

import SidebarRootLink from './SidebarRootLink'

export default class Sidebar extends React.Component {
  static propTypes = {
    nav: PropTypes.array.isRequired,
    activeSection: PropTypes.string,
    isMobile: PropTypes.bool
  }

  state = {
    openSection: null
  }

  capitalizeSectionTitle = compose(
    join(''),
    juxt([
      compose(
        toUpper,
        head
      ),
      tail
    ])
  )

  sectionIsOpen = section =>
    or(
      equals(section, this.state.openSection),
      equals(section, this.props.activeSection)
    )

  _toggleSection = section => {
    this.setState(prevState => {
      if (prevState.openSection !== section) {
        return { openSection: section }
      } else {
        return { openSection: null }
      }
    })
  }

  normalizeNavBlock = block => {
    const nav = []

    block.map(item => {
      if (!item.node.fields.isIndex) {
        nav.push({
          title: item.node.frontmatter.title,
          url: item.node.fields.slug
        })
      }
    })

    return nav
  }

  navBlockIndex = block => {
    const hasIndex = item => item.node.fields.isIndex === true
    return filter(hasIndex, block)
  }

  getNavBlockIndexSlug = block =>
    this.navBlockIndex(block)[0]['node']['fields']['slug']

  render() {
    const { isMobile } = this.props
    return (
      <>
        {this.props.nav && (
          <aside
            className={cx(
              { 'dn db-l fixed-l br b--light-gray ph4 pt4 vh-100': !isMobile },
              { 'db pt2': isMobile },
              'overflow-auto z-2'
            )}
            css={{
              width: style.sidebar.width
            }}
          >
            <nav>
              <ul className="list ma0 pl0">
                {this.props.nav.map((item, index) => (
                  <React.Fragment key={index}>
                    {length(this.normalizeNavBlock(item.edges)) > 0 && (
                      <li key={index}>
                        <SidebarRootLink
                          title={this.capitalizeSectionTitle(
                            startCase(item.section)
                          )}
                          isOpen={this.sectionIsOpen(item.section)}
                          toggleSection={() =>
                            this._toggleSection(item.section)
                          }
                          itemsLength={length(this.navBlockIndex(item.edges))}
                          href={
                            length(this.navBlockIndex(item.edges)) > 0
                              ? this.getNavBlockIndexSlug(item.edges)
                              : false
                          }
                        />
                        <ul
                          className={`list pl2 ml4 mb4 ${
                            this.sectionIsOpen(item.section) ? '' : 'dn'
                          }`}
                        >
                          {this.normalizeNavBlock(item.edges).map(
                            (item, index) => (
                              <li key={index}>
                                <Link
                                  to={item.url}
                                  activeClassName="spree-green fw5"
                                  className="link gray db mv2 fw4"
                                >
                                  {item.title}
                                </Link>
                              </li>
                            )
                          )}
                        </ul>
                      </li>
                    )}
                  </React.Fragment>
                ))}
              </ul>
            </nav>
          </aside>
        )}
      </>
    )
  }
}
