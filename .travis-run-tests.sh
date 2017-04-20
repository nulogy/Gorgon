echo "Running end to end tests"

pushd tests/end_to_end
bundle install
bundle exec gorgon listen &
LISTENER_PID=$!
popd
bundle exec rspec spec
kill -9 $LISTENER_PID
