This app is used to test [Gorgon](https://github.com/nulogy/Gorgon).

* Run `./run_test.sh` for running tests and comparing output with correct_test_result.out
* Run `./update_correct_test_result.sh` for updating correct_test_result.out with current output

## Set up for localhost testing
1. Clone gorgon into a directory. We will assume `~/src/gorgon` for the purpose of these instructions. If you use a different directory, then you will need to modify the path in `Gemfile` accordingly.
1. Run `rabbitmq-server` in the background
1. `cp gorgon_listener.json.example gorgon_listener.json`
1. `cp gorgon.json.example gorgon.json`
1. `bundle install`
1. `gorgon listen`
1. In a new tab/window, execute `gorgon`.

### Installation Troubleshooting

* If you have trouble installing the *eventmachine* gem on Mac OS X because of an issue with building with openssl, then try using Homebrew's version of `openssl`:
  * `brew install openssl`
  * `brew link openssl --force`

## Debugging Tools

* Use `rspec_runner.rb` to debug Gorgon's RspecRunner. You can use `binding.pry`. To use it, run: `bundle exec ruby rspec_runner.rb`
