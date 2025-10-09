<p align="center">
  <a href="https://spreecommerce.org">
    <img alt="Spree Commerce - Open Source eCommerce Platform" src="https://github.com/spree/spree/assets/12614496/ff5372a4-e906-458e-83b6-7927ba0629c1" />
  </a>
</p>

<h1 align="center">🛍️ Spree Enhanced Edition</h1>

<p align="center">
  A modernized, modular, and developer-friendly fork of the <a href="https://spreecommerce.org">Spree Commerce</a> platform.<br />
  Built with ❤️ on Ruby on Rails — refactored and reimagined for 2025.
</p>

<p align="center">
  <a href="https://spreecommerce.org/announcing-spree-5-the-biggest-open-source-release-ever/">Spree 5</a> ·
  <a href="https://spreecommerce.org">Website</a> ·
  <a href="https://spreecommerce.org/docs/">Documentation</a> ·
  <a href="https://slack.spreecommerce.org">Slack</a> ·
  <a href="https://github.com/spree/spree_starter/">Starter</a> ·
  <a href="https://demo.spreecommerce.org">Demo</a> ·
  <a href="https://spreecommerce.org/pricing/">Pricing</a> ·
  <a href="https://github.com/spree/spree/milestones?direction=asc&sort=due_date&state=open">Roadmap</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Ruby-3.2-red?logo=ruby" alt="Ruby Version" />
  <img src="https://img.shields.io/badge/Rails-7.x-red?logo=rubyonrails" alt="Rails Version" />
  <img src="https://github.com/spree/spree/actions/workflows/ci.yml/badge.svg" alt="CI Status" />
  <img src="https://img.shields.io/github/license/spree/spree" alt="License" />
  <img src="https://img.shields.io/maintenance/yes/2025" alt="Maintained" />
  <img src="https://img.shields.io/gem/dt/spree" alt="Gem Downloads" />
  <img src="https://img.shields.io/badge/slack%20members-7K-blue" alt="Slack Members" />
</p>

---

## 🚀 What’s New in the Enhanced Edition

- ✅ Modern Ruby syntax (`&.`, guards, enums, services)
- 🧩 Modular architecture with `app/services/` and `app/presenters/`
- 🌐 Improved API (CORS, pagination, Blueprinter serializers)
- ⚙️ Built-in GitHub Actions (tests + lint)
- 🎨 Optional TailwindCSS UI integration
- 🧠 Better developer documentation & contribution flow

---

## ⚙️ Quick Start

```bash
git clone https://github.com/YOUR_USERNAME/spree-enhanced.git
cd spree-enhanced
bundle install
rails db:setup
rails server
