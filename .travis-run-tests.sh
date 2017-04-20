echo "Running end to end tests"

cd tests/end_to_end
bundle install
bundle exec gorgon listen &
LISTENER_PID=$!
cd -
bundle exec rspec spec
kill -9 $LISTENER_PID
