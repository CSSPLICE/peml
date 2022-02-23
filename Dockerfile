FROM ruby:3.0

# throw errors if Gemfile has been modified since Gemfile.lock
# RUN bundle config --global frozen 1
RUN bundle config unset frozen

COPY . /peml

WORKDIR peml 
#/usr/src/app

#COPY Gemfile Gemfile.lock ./
RUN bundle install --full-index

#COPY . .

CMD ruby /peml/runner.rb