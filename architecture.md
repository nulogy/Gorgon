Architecture
---------------------

By running `gorgon start`, the originating computer will publish a *job definition* to the AMQP server. This object contains all of the information required to run the tests:

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
