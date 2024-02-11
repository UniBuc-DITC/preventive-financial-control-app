# Application for the Preventive Financial Control office

## Description

This repository contains the source code for the web app used by the [Preventive Financial Control office](https://unibuc.ro/despre-ub/organizare/administratie/biroul-control-financiar-preventiv/) of the [University of Bucharest](https://unibuc.ro/). It is built using the [Ruby on Rails](https://rubyonrails.org/) framework.

## Development environment setup guide

First, you need to have [Ruby](https://www.ruby-lang.org/en/) installed. Check the [`.ruby-version`](.ruby-version) file to determine which version you need. On Windows, you can get it by downloading [Ruby Installer](https://rubyinstaller.org/). On Mac OS or Linux, we recommend managing your Ruby install through [`rbenv`](https://github.com/rbenv/rbenv).

You will also need to have [Node.js](https://nodejs.org/en) installed for the compression step of the asset pipeline.

For development we recommend using an IDE such as [Visual Studio Code](https://code.visualstudio.com/) (see [this guide](https://code.visualstudio.com/docs/languages/ruby) for enabling Ruby support) or [RubyMine](https://www.jetbrains.com/ruby/).

Once you have Ruby and Node.js on your machine, you can install the package dependencies by running `bundle install` in the project's root directory.

Start a local development server by running `rails server`. The app will be available in your browser at `http://localhost:3000/`.

## License

The code is [licensed](LICENSE.txt) under the permissive MIT license.
