FROM node:24-bookworm-slim AS frontend
WORKDIR /web
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build

FROM ruby:3.4.8-slim-bookworm AS app
RUN apt-get update -qq && apt-get install --no-install-recommends -y build-essential libpq-dev libyaml-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /app
ENV RAILS_ENV=production BUNDLE_WITHOUT=development:test
COPY Gemfile Gemfile.lock ./
RUN bundle install && rm -rf /usr/local/bundle/cache
COPY . .
COPY --from=frontend /web/dist/ ./public/
RUN groupadd --gid 1000 app && useradd --uid 1000 --gid app --create-home app && chown -R app:app /app
USER app
EXPOSE 3000
CMD ["bash", "-c", "bin/rails db:prepare && bin/rails demo:cleanup && exec bin/rails server -b 0.0.0.0 -p 3000"]
