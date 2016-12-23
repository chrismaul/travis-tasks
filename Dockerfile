FROM ruby:2.3.1-onbuild

ENTRYPOINT [ "bundle", "exec", "je", "sidekiq", "-c", "25", "-r", "./lib/travis/tasks.rb", "-q", "notifications", "-q", "campfire", "-q", "email", "-q", "flowdock", "-q", "github_commit_status", "-q", "github_status", "-q", "hipchat", "-q", "irc", "-q", "webhook", "-q", "slack", "-q", "pushover" ]
ENV RACK_ENV production
