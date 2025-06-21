# Application for the Preventive Financial Control office

## Description

This repository contains the source code for the web app used by the [Preventive Financial Control office](https://unibuc.ro/despre-ub/organizare/administratie/biroul-control-financiar-preventiv/) of the [University of Bucharest](https://unibuc.ro/). It is built using the [Ruby on Rails](https://rubyonrails.org/) framework.

## Development environment setup guide

For development, we recommend using an IDE such as [Visual Studio Code](https://code.visualstudio.com/) (see [this guide](https://code.visualstudio.com/docs/languages/ruby) for enabling Ruby support) or [RubyMine](https://www.jetbrains.com/ruby/).

### Installing Ruby and Node.js

First, you need to have [Ruby](https://www.ruby-lang.org/en/) installed. Check the [`.ruby-version`](.ruby-version) file to determine which version you need. On Windows, you can get it by downloading [Ruby Installer](https://rubyinstaller.org/). On Mac OS or Linux, we recommend managing your Ruby install through [`rbenv`](https://github.com/rbenv/rbenv).

Check that Ruby got successfully installed by running the following command in a terminal:

```shell
ruby --version
```

You will also need to have [Node.js](https://nodejs.org/en) installed for the compression step of the asset pipeline.

Check that Node.js is installed by running the following command:

```shell
node --version
```
### Installing native libraries

You will need to install a few native libraries required by some of the dependencies.

If using RubyInstaller for Windows, run the following command in a terminal running as administrator:

```shell
ridk exec sh -c 'pacman -S ${MINGW_PACKAGE_PREFIX}-postgresql'
```

For Ubuntu or Debian, run:

```shell
sudo apt install libpq-dev
```

### Installing dependencies

Once you have Ruby and Node.js on your machine, you can install the package dependencies by running `bundle install` in the project's root directory.

### Configuring API credentials

The app relies on [Microsoft Entra ID](https://www.microsoft.com/en-us/security/business/identity-access/microsoft-entra-id) for authentication. You will have to [create an app registration](https://learn.microsoft.com/en-us/entra/identity-platform/quickstart-register-app) on the Microsoft identity platform to be able to sign in.

You can edit the (encrypted) credentials file by running:

```shell
rails credentials:edit
```

then add a section with the following structure:

```yaml
# Credentials for Microsoft Entra ID
microsoft_identity_platform:
  tenant_id: <tenant ID>
  client_id: <client ID>
  client_secret: <client secret>
```

### Starting the database

The app needs to connect to a [PostgreSQL](https://www.postgresql.org/) instance to use as a database.

Assuming that you've got [Docker](https://www.docker.com/) and the [Docker Compose](https://docs.docker.com/compose/) plugin installed, you can run the following command to start a local Postgres instance:

```shell
docker compose up
```

### Creating and seeding the database

To create the database structure, you can either run the migrations by using `rails db:migrate` (which will not destroy the existing data) or recreate the database from scratch using `rails db:schema:load`.

You should then set the `ADMIN_EMAIL` environment variable to a Microsoft 365 user e-mail and run `rails db:seed` to seed the database. This will create an admin user account corresponding to the `ADMIN_EMAIL` variable and load some predefined entities from disk. Example call:

```
ADMIN_EMAIL='example@unibuc.ro' rails db:seed
```

### Starting the development server

Start a local development server by running `rails server`. The app will be available in your browser at `http://localhost:3000/`.

### Running the tests

To run the automated tests, use `rails test`. To also obtain code coverage data, set the `COVERAGE` environment variable to a non-empty/truthy value before running the command.

## License

The code is [licensed](LICENSE.txt) under the permissive MIT license.
