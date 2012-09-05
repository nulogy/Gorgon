Gorgon
=====================

About
---------------------

Gorgon provides a method for distributing the workload of running a ruby test suites. It relies on amqp for message passing, and rsync for the synchronization of source code.

Usage
---------------------

To queue the current test suite, run `bundle exec gorgon start`, or `bundle exec gorgon`. _gorgon_ will read the application configuration out of _gorgon.json_, connect to the AMQP server, and publish the job.

In order for the job to run, _gorgon job listeners_ must be started that can process the job. To start a gorgon listener, run `bundle exec gorgon listen`. This command will read the listener configuration out of _gorgon\_listener.json_, then start the listener process in the background.

Configuration
---------------------

### gorgon.json
This file contains project-specific settings for gorgon, such as:

* A glob for generating the list of test files
* The connection information for AMQP
* Information about how clients can rsync the working directory

### gorgon_listener.json
This file contains the listener-specific settings, such as:

* How many worker slots are provided by this listener
* The connection information for AMQP
* The file used for logs

Architecture
---------------------

By running `bundle exec gorgon start`, the originating computer will publish a *job definition* to the AMQP server. This object contains all of the information required to run the tests:

* The rsync information with which to fetch the source tree
* The name of a AMQP queue that contains the list of files that require testing
* The name of a AMQP exchange to send replies to
* Application-specific setup/teardown, either per-job or per-worker [scheduled for post-alpha]

The job listener subscribes to the job publish event, and maintains its own queue of jobs. When a job has available *worker slots*, it will prepare the workspace:

* Create a unique temporary workspace directory for the job
* Rsync the source tree to the temporary workspace
* Run per-job application-specific setup [scheduled for post-alpha]
* Invoke *n* workers, where *n* is the number of available *worker slots*.

To invoke a job worker, the listener passes the name of the *file queue*, *reply queue*, and *listener queue* to the worker initialization. After all workers have been started, the listener will block until an event appears on the *listener queue*.

The worker process will run any application-specific startup, start a test environment, and load a stub test file that dynamically pulls files out of the *file queue*. It runs the test, posts the results to the *reply queue*, and repeats until the *file queue* is empty. When the *file queue* becomes empty, the worker runs application-specific teardown, then reports its completion to the *listener queue*, and shuts down.
