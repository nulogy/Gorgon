Gorgon
=====================

About
---------------------

Gorgon provides a method for distributing the workload of running ruby test suites. It relies on amqp for message passing, and rsync for the synchronization of source code.

Installing Gorgon
-----------------
1. `sudo apt-get install rabbitmq-server`
1. When you run gorgon, every listener will use rsync to pull the directory tree from origin; therefore, you need passwordless ssh login from every listener to origin (even if origin and listener are on the same host). Follow [these steps](http://linuxconfig.org/Passwordless_ssh).
1. cd to your project
1. `gem install gorgon`
1. if using rails, `gorgon init rails` will create initial files for a typical rails project. Otherwise, you can use `gorgon init`
1. check gorgon.json to see and modify any necessary setting
1. add the following lines to your _database.yml_ file

```yaml
remote_test: &remote_test
  <<: *defaults
  database: <my-app>_remote_test_<%=ENV['TEST_ENV_NUMBER']%>
  min_messages: warning
```

Where `<<: *defaults` are the default values used in _database.yml_, like for example, adapter, username, password, and host. Replace `<my-app>` with a name to identify this application's dbs

Installing listener as a Daemon process (Ubuntu 9.10 or later)
----------------------------------------------------------------
1. run `gorgon install_listener` from the directory where gorgon.json is
1. run `gorgon ping` to check if the listener is running

Try it out!
-----------
1. run `gorgon` to run all the tests.

**NOTE:** if you get `cannot load such file -- qrack/qrack (LoadError)`, just add `gem 'gorgon', '~> 0.4.1' , :group => :remote_test` to your Gemfile, and run tests using `bundle exec gorgon`

Also note that these steps are **not** meant to work on every project, they will only give you initial settings. You will probably have to modify the following files:
* gorgon.json
* test/gorgon_callbacks/after\_sync.rb
* test/gorgon_callbacks/before\_creating\_workers.rb
* test/gorgon_callbacks/before\_start.rb
* test/gorgon_callbacks/after\_complete.rb
* ~/.gorgon/gorgon_listener.json

If you modify ~/.gorgon/gorgon_listener.json, make sure you restart the listener by running `sudo restart gorgon`

Usage
---------------------

To queue the current test suite, run `gorgon start`, or `gorgon`. _gorgon_ will read the application configuration out of _gorgon.json_, connect to the AMQP server, and publish the job.

If you want to run the listener manually (didn't install Daemon process), you must run _gorgon job listeners_. To start a gorgon listener, run `gorgon listen`. This command will read the listener configuration out of _gorgon\_listener.json_, then start the listener process in the background.

Configuration
---------------------

### gorgon.json
This file contains project-specific settings for gorgon, such as:

* The connection information for AMQP
* Information about how clients can rsync the working directory (optional)
* Files that can be excluded by rsync
* Files containing Ruby code to be used as callbacks
* A glob for generating the list of test files
* The file used for Originator's logs

See [gorgon.json example](/Fitzsimmons/Gorgon/blob/master/gorgon.json.sample) for more details.

### gorgon_listener.json
This file contains the listener-specific settings, such as:

* The connection information for AMQP
* How many worker slots are provided by this listener
* The file used for logs

See [gorgon_listener.json example](/Fitzsimmons/Gorgon/blob/master/gorgon_listener.json.sample) for more details.

### Manually setting up gorgon listener as a daemon process (Ubuntu 9.10 or later)
If `gorgon install_listener` didn't work for you, you can try [these steps](/Fitzsimmons/Gorgon/blob/master/daemon_with_upstart_and_rvm.md)

Contributing
---------------------
Read overview [architecture](/Fitzsimmons/Gorgon/blob/master/architecture.md)

Credits
---------------------
Gorgon is maintained by:
* Justin Fitzsimmons
* Arturo Pie
* Sean Kirby
* Clemens Park
* Victor Savkin

Gorgon is funded by [Nulogy Corp](http://www.nulogy.com/).
Thank you to all the [contributors](/Fitzsimmons/Gorgon/graphs/contributors).
