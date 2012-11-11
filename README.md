Gorgon
=====================

About
---------------------

Gorgon provides a method for distributing the workload of running ruby test suites. It relies on amqp for message passing, and rsync for the synchronization of source code.

Usage
---------------------

To queue the current test suite, run `bundle exec gorgon start`, or `bundle exec gorgon`. _gorgon_ will read the application configuration out of _gorgon.json_, connect to the AMQP server, and publish the job.

In order for the job to run, _gorgon job listeners_ must be started that can process the job. To start a gorgon listener, run `bundle exec gorgon listen`. This command will read the listener configuration out of _gorgon\_listener.json_, then start the listener process in the background.

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

See [gorgon.json example](https://github.com/Fitzsimmons/Gorgon/blob/master/gorgon.json.sample) for more details.

### gorgon_listener.json
This file contains the listener-specific settings, such as:

* The connection information for AMQP
* How many worker slots are provided by this listener
* The file used for logs

See [gorgon_listener.json example](https://github.com/Fitzsimmons/Gorgon/blob/master/gorgon_listener.json.sample) for more details.

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
Thank you to all the [contributors](/contributors).