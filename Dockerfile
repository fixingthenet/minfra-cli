FROM ruby:2.7.1

ENV APP_DIR /code
WORKDIR $APP_DIR

ADD Gemfile $APP_DIR
#ADD Gemfile.lock $APP_DIR
RUN bundle install --jobs 4 --retry 3
ADD . $APP_DIR

CMD /bin/bash

