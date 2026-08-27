# Spree Commerce Documentation project

This directory contains the documentation for Spree Commerce located at [https://spreecommerce.org/docs](https://spreecommerce.org/docs).

## Contributing

We welcome contributions to the documentation! We use [Mintlify](https://mintlify.com/docs/quickstart) to build the documentation.

To run the documentation locally, you will need to install the Mintlify CLI.

> [!IMPORTANT]
> Mintlify requires Node.js version 20+ to run.

```bash
npm i -g mint
```

Then you can run the documentation locally. From the repository root:

```bash
pnpm docs:dev
```

This serves the documentation at [http://localhost:3333](http://localhost:3333).

The port is pinned deliberately. Running `mint dev` on its own picks port 3000 and silently moves to 3001, 3002 and so on when that is taken — which, in a checkout that also runs a Rails server and a dashboard, means the docs land somewhere different each time. If you do run `mint dev` directly, pass the port yourself:

```bash
cd docs && mint dev --port 3333
```

## License

Documentation located in this directory is licensed under the [CC BY 4.0](LICENSE.md) license.
