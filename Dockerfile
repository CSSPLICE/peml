FROM ruby:3.0

# throw errors if Gemfile has been modified since Gemfile.lock
# RUN bundle config --global frozen 1
RUN bundle config unset frozen

COPY . /peml

WORKDIR peml 
#/usr/src/app

#COPY Gemfile Gemfile.lock ./

#Matching the bundler version with the version that created the Gemfile
RUN gem install bundler:2.3.7
RUN bundle _2.3.7_ install

RUN bundle install --full-index


#COPY . .

CMD ruby /peml/runner.rb