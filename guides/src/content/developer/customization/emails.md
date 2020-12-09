---
title: 'Emails Customization'
section: customization
order: 10
---

<alert kind="warning">
  This section is only applicable to [Spree 4.2](/release_notes/4_2_0.html) or newer
</alert>

## Overview

Spree uses [postmark templates](https://github.com/wildbit/postmark-templates), as a base for all transactional emails.

## Email previews

Spree offers emails preview generator for development purposes.
To generate them, use command:

`bundle exec rails g spree:mailers_preview`

After that, start rails server locally and go to:
`localhost:3000/rails/mailers`

(it requires seeded development database in order to work properly)
