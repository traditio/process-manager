Task. The process manager
=========================


Description.


Let us have several processes with several threads each which do some abstract work.
A thread can have some different states. All threads work independently. Let us have the process manager which monitors all these processes and threads.

Process manager features:

1. It can run a new process with needed count of threads.
2. It sends the command to the process to terminate safe. Threads have to finish current jobs.
3. It sends the command to the process to interrupt. Threads don't wait for job finishing.
4. It knows the state of all threads and processes.



Conditions
1. Each thread has only 5 states. It changes states in random periods of time (1..10 seconds).
2. The process belongs to only one manager.
3. Only one manager can be started.


Instruction
-----------

    rvm install 1.9.3
    rvm gemset create procman
    rvm use 1.9.3@procman

    bundle
    bundle exec rake

To start the process manager:

    bundle exec rake master_process

To start the web interface:

    bundle exec rake web_manager



