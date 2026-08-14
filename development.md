# Development Notes

Some good things to know when working on this project.

## Ruby setup

1. Check the `./.ruby-version` file and make sure you have that version or later installed. Having that specific version
   installed would be best. Using a version manager like RVM would be useful if you have another version of ruby already
   installed.

   Note: MacOS comes wth a Ruby version preinstalled. This can be confusing, RVM or rbenv can help with getting around
   that.

2. TO use docker for development, you can run the container with a volume. You can use `./Dockerfile-dev`
   (Check for an example)
3. To build the gem run `$ gem build peml.gemspec`
4. To install the gem run `$ gem install peml-0.1.1.gem` 