Rsync Transport Documentation
=============================

In gorgon.json, you can change how files are uploaded from Originator to File Server and downloaded from File Server to Listeners.
This setting is "rsync_transport" which could be either "ssh" or "anonymous"

SSH Transport
-------------

If you are using this setting, originator and all listeners should have SSH passwordless access to File Server. You can follow [these steps](http://www.linuxproblem.org/art_9.html) to setup SSH login without password. 

Anonymous Transport
-------------------

If you are using this setting, you need to run the following in the File Server:

  ```bash
  mkdir -p ~/.gorgon/file_dir             # here is where gorgon will push files under test
  gorgon start_rsync ~/.gorgon/file_dir
  ```