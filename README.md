# 🛍️ Spree Enhanced Edition

A modern, developer-friendly fork of the original [Spree Commerce](https://github.com/spree/spree) platform — built for performance, scalability, and maintainability.  
This edition refactors legacy code, improves CI/CD workflows, and introduces a more modular architecture for next-generation e-commerce apps.

---

## 🚀 Features

- ⚡ **Modern Ruby on Rails (v7+) support**
- 🧩 **Modular Spree architecture** with simplified controllers
- 🧠 **Enhanced code quality** using RuboCop, RSpec, and GitHub Actions
- 🔐 **Improved security defaults**
- 🧱 **Developer-first structure** with lightweight dependency management
- 📦 **Plug-and-play customization layer**

---

## 🧰 Tech Stack

| Layer      | Technology                |
|------------|--------------------------|
| Framework  | Ruby on Rails 7          |
| Language   | Ruby 3.2+                |
| Database   | PostgreSQL               |
| Linting    | RuboCop + rubocop-rspec  |
| Testing    | RSpec                    |
| CI/CD      | GitHub Actions           |
| Frontend   | Turbo + Stimulus (Hotwire ready) |

---

## ⚙️ Setup Instructions

### 1️⃣ Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/spree-enhanced-edition.git
cd spree-enhanced-edition
```

### 2️⃣ Install Dependencies

```bash
bundle install
yarn install
```

### 3️⃣ Set Up the Database

```bash
rails db:create db:migrate db:seed
```

### 4️⃣ Start the Server

```bash
rails server
```

### 5️⃣ Access the App

Open [http://localhost:3000](http://localhost:3000) in your browser.

---

## 📚 Documentation

- [Spree Commerce Docs](https://spreecommerce.org/docs/)
- [Ruby on Rails Guides](https://guides.rubyonrails.org/)
- [Hotwire Docs](https://hotwired.dev/)

---

## 🤝 Contributing

Pull requests and issues are welcome!  
See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## 🛡️ License

Distributed under the MIT License.  
See [LICENSE](LICENSE) for details.