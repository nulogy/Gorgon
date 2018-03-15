Architecture
---------------------

[Gorgon](https://github.com/nulogy/Gorgon/) distributes a test suite across multiple machines. So you can use all the computer power in your office to run your tests in parallel.

These are the main components of Gorgon's architecture:

* *originator*: program that we run in the terminal to start running tests.
* *listener*: long living program running as background process on every remote host that will run tests. It will wait for a *job definition* form *originator*, and fork a *worker manager*.
* *file server*: middleman host used to transfer source code from *originator* to *listeners*.
* *worker manager*: process that forks *workers*.
* *worker*: process that runs test files and sends results back to *originator*
* [*RabbitMQ*](http://www.rabbitmq.com/): message broker running on a fixed host. It's used to communicate between *originator*, and *listeners*, *worker managers* and *workers*.

![image](https://www.lucidchart.com/publicSegments/view/540e47ae-2288-4569-880b-4c780a00596c/image.png=600x)

Every machine needs to run a *listener*, that should be launched on system startup. Between *originator* and *listeners* we have a *file server* and *RabbitMQ*. When we run Gorgon, *originator* will push all files to the *file server*, and add a *job definition* to a *RabbitMQ* queue that all listener are listening to.

A *job definition* contains:

* The rsync information with which to fetch the source tree from *file server*
* The name of a RabbitMQ queue that contains the list of files that require testing
* The name of a RabbitMQ exchange to send replies to
* Application-specific setup/teardown, either per-job or per-worker (callbacks)

When a *listener* receives a *job definition*, it:

* Creates a unique temporary workspace directory for the job
* Rsync the source tree from *file server* to the temporary workspace
* Runs after_sync callback
* Invoke a WorkerManager

After WorkerManager starts, it:

* Runs before_creating_workers callback
* Forks n workers, where n is the number of available worker slots specified in [gorgon configuration](https://github.com/nulogy/Gorgon/blob/master/gorgon_listener.json.sample).
* Subscribes to a queue where originator can send a cancel_job message

Each Worker:

* Runs before_start callback
* Keeps popping files one at a time until *file queue* is empty. For every file, it posts a *start message*, runs file using correct *test runner* (RSpec or MiniTest), and sends a *finish message* to *originator* with the results through the reply queue.
* Runs after_complete callback
