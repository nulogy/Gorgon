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

Architecture
---------------------

By running `bundle exec gorgon start`, the originating computer will publish a *job definition* to the AMQP server. This object contains all of the information required to run the tests:

* The rsync information with which to fetch the source tree
* The name of a AMQP queue that contains the list of files that require testing
* The name of a AMQP exchange to send replies to
* Application-specific setup/teardown, either per-job or per-worker (callbacks)

The job listener subscribes to the job publish event, and maintains its own queue of jobs. When a job has available *worker slots*, it will prepare the workspace:

* Create a unique temporary workspace directory for the job
* Rsync the source tree to the temporary workspace
* Run after_sync callback
* Invoke a WorkerManager

After WorkerManager starts, it will:
* Run before\_creating\_workers callback
* Fork *n* workers, where *n* is the number of available *worker slots*.
* Subscribe to a queue where originator can send a cancel_job message

Each Worker will:
* Run before_start callback
* Pop a file from file queue and run it until file queue is empty, or WorkerManager sends an INT signal. For each file, it post a 'start_message' and a 'finish_message' with the results to the *reply queue*
* Run after_complete callback

To invoke the worker manager, the listener passes the name of the *file queue*, *reply queue*, and *listener queue* to the worker manager initialization, and then it will block until worker manager finishes.

Contributors
---------------------
* Justin Fitzsimmons
* Arturo Pie
* Sean Kirby
* Clemens Park
* Victor Savkin

Gorgon is funded by [Nulogy Corp](http://www.nulogy.com/).