FROM ruby:4.0.1

# Tell Rails this is a production environment
ENV RAILS_ENV='production' \
    BUNDLE_DEPLOYMENT='1' \
    BUNDLE_WITHOUT='development test'

# Install binary package dependencies
COPY config/docker/scripts/install-deps.sh /tmp/install-deps.sh
RUN bash /tmp/install-deps.sh

# Run and own only the runtime files as a non-root user for security
RUN groupadd rails && \
    useradd --system --create-home --shell /bin/bash --gid rails rails && \
    mkdir /app && \
    chown -R rails:rails /app

# Switch to the newly-created user and app directory
USER rails:rails
WORKDIR /app

# Install dependencies in an intermediate step,
# to allow caching the image.
COPY --chown=rails:rails Gemfile Gemfile.lock ./

RUN bundle install
# Precompile gem code for faster boot times
RUN bundle exec bootsnap precompile --gemfile

# Copy the rest of the source files
COPY --chown=rails:rails . /app

# Precompile app code
RUN bundle exec bootsnap precompile app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN RAILS_PRECOMPILE_ASSETS=1 SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

EXPOSE 3000
EXPOSE 3001

# Entrypoint prepares the database.
ENTRYPOINT ["/app/bin/docker-entrypoint"]

CMD ["./bin/rails", "server"]
