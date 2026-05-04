#!/bin/bash
# build_and_install.sh

# Exit immediately if a command exits with a non-zero status
set -e

# Build the gem
gem build peml.gemspec

# Install the built gem (Remember to update version number as needed)
gem install peml-0.1.1.gem
